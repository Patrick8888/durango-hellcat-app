import CoreBluetooth
import Foundation
import Observation

/// Talks ELM327 to the adapter: initialises it, polls live values in a loop and
/// reads trouble codes. Read-only on purpose: the Secure Gateway in the 2025 Durango
/// blocks writes without an authorised diagnostic tool.
@Observable
final class OBDManager {
    struct Device: Identifiable {
        let id: UUID
        let name: String
        var rssi: Int
        let peripheral: CBPeripheral

        var looksLikeOBD: Bool {
            let lower = name.lowercased()
            return ["obd", "elm", "vlink", "vgate", "cx", "mx"].contains { lower.contains($0) }
        }
    }

    enum Status: Equatable {
        case disconnected
        case bluetoothOff
        case scanning
        case connecting
        case initializing
        case live
        case demo
        case failed(String)

        var label: String {
            switch self {
            case .disconnected: "Nicht verbunden"
            case .bluetoothOff: "Bluetooth ist aus"
            case .scanning: "Suche Adapter…"
            case .connecting: "Verbinde…"
            case .initializing: "Initialisiere Adapter…"
            case .live: "Verbunden"
            case .demo: "Demo-Modus"
            case .failed(let message): "Fehler: \(message)"
            }
        }
    }

    struct LiveData {
        var rpm: Double?
        var speed: Double?
        var coolantTemp: Double?
        var intakeTemp: Double?
        var oilTemp: Double?
        var boostBar: Double?
        var throttle: Double?
        var voltage: Double?
    }

    private(set) var status: Status = .disconnected
    private(set) var devices: [Device] = []
    private(set) var live = LiveData()
    private(set) var adapterInfo: String?
    /// PIDs the car did not answer three times in a row; they are no longer polled.
    private(set) var unsupported: Set<UInt8> = []

    var isStreaming: Bool { status == .live || status == .demo }

    @ObservationIgnored private let ble = BLEConnection()
    @ObservationIgnored private var queue: [(command: String, completion: (String) -> Void)] = []
    @ObservationIgnored private var inFlight: ((String) -> Void)?
    @ObservationIgnored private var timeoutWork: DispatchWorkItem?
    @ObservationIgnored private var pollIndex = 0
    @ObservationIgnored private var failures: [UInt8: Int] = [:]
    @ObservationIgnored private var baroKPa = 101.3
    @ObservationIgnored private var demoTimer: Timer?
    @ObservationIgnored private var demoTime = 0.0

    /// RPM and speed appear twice so they refresh faster than the slow-moving temperatures.
    private let pollList: [OBDPID] = [
        .rpm, .speed, .manifoldPressure, .throttle,
        .rpm, .speed, .coolantTemp, .intakeTemp, .oilTemp, .moduleVoltage,
    ]

    init() {
        ble.onStateChange = { [weak self] state in self?.handle(state) }
        ble.onDiscover = { [weak self] peripheral, rssi in self?.discovered(peripheral, rssi: rssi) }
        ble.onResponse = { [weak self] response in self?.received(response) }
    }

    // MARK: - Public API

    func startScan() {
        devices = []
        ble.startScan()
    }

    func stopScan() {
        ble.stopScan()
    }

    func connect(_ device: Device) {
        ble.connect(device.peripheral)
    }

    func disconnect() {
        if status == .demo {
            stopDemo()
        } else {
            ble.disconnect()
        }
    }

    func readTroubleCodes(completion: @escaping ([String]?) -> Void) {
        switch status {
        case .demo:
            completion([])
        case .live:
            enqueue("03") { response in
                if response == "TIMEOUT" {
                    completion(nil)
                } else if response.uppercased().contains("NO DATA") {
                    completion([])
                } else {
                    completion(OBDParser.troubleCodes(in: response))
                }
            }
        default:
            completion(nil)
        }
    }

    func startDemo() {
        status = .demo
        ble.disconnect()
        demoTime = 0
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tickDemo()
        }
    }

    // MARK: - Connection state

    private func handle(_ state: BLEConnection.State) {
        guard status != .demo else { return }
        switch state {
        case .bluetoothOff:
            status = .bluetoothOff
        case .idle:
            if status != .disconnected { resetSession() }
            status = .disconnected
        case .scanning:
            status = .scanning
        case .connecting:
            status = .connecting
        case .connected:
            status = .initializing
            initializeAdapter()
        case .failed(let message):
            resetSession()
            status = .failed(message)
        }
    }

    private func discovered(_ peripheral: CBPeripheral, rssi: Int) {
        if let index = devices.firstIndex(where: { $0.id == peripheral.identifier }) {
            devices[index].rssi = rssi
            return
        }
        let device = Device(id: peripheral.identifier, name: peripheral.name ?? "Unbekannt",
                            rssi: rssi, peripheral: peripheral)
        // Likely adapters go to the top; otherwise keep discovery order so the list does not jump.
        if device.looksLikeOBD {
            devices.insert(device, at: 0)
        } else {
            devices.append(device)
        }
    }

    private func initializeAdapter() {
        // Reset, no echo, no linefeeds, no spaces, no headers, automatic protocol.
        for command in ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"] {
            enqueue(command) { _ in }
        }
        enqueue("ATI") { [weak self] response in
            self?.adapterInfo = response
        }
        // The first OBD request makes the adapter search for the protocol, which can take a few seconds.
        enqueue("0100") { _ in }
        enqueue(OBDPID.barometricPressure.command) { [weak self] response in
            if let bytes = OBDParser.dataBytes(for: OBDPID.barometricPressure.code, in: response),
               let value = OBDPID.barometricPressure.decode(bytes) {
                self?.baroKPa = value
            }
            self?.status = .live
            self?.pollNext()
        }
    }

    private func resetSession() {
        queue.removeAll()
        inFlight = nil
        timeoutWork?.cancel()
        timeoutWork = nil
        live = LiveData()
        failures = [:]
        unsupported = []
        adapterInfo = nil
    }

    // MARK: - Command queue

    private func enqueue(_ command: String, completion: @escaping (String) -> Void) {
        queue.append((command, completion))
        pump()
    }

    private func pump() {
        guard inFlight == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        inFlight = next.completion
        let work = DispatchWorkItem { [weak self] in self?.received("TIMEOUT") }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
        ble.send(next.command)
    }

    private func received(_ response: String) {
        timeoutWork?.cancel()
        timeoutWork = nil
        guard let completion = inFlight else { return }
        inFlight = nil
        completion(response)
        pump()
    }

    // MARK: - Polling

    private func pollNext() {
        guard status == .live else { return }
        let candidates = pollList.filter { !unsupported.contains($0.code) }
        guard !candidates.isEmpty else { return }
        let pid = candidates[pollIndex % candidates.count]
        pollIndex += 1
        enqueue(pid.command) { [weak self] response in
            self?.store(pid, response: response)
            self?.pollNext()
        }
    }

    private func store(_ pid: OBDPID, response: String) {
        guard let bytes = OBDParser.dataBytes(for: pid.code, in: response), let value = pid.decode(bytes) else {
            let count = (failures[pid.code] ?? 0) + 1
            failures[pid.code] = count
            if count >= 3 { unsupported.insert(pid.code) }
            return
        }
        failures[pid.code] = 0

        switch pid.code {
        case OBDPID.rpm.code: live.rpm = value
        case OBDPID.speed.code: live.speed = value
        case OBDPID.coolantTemp.code: live.coolantTemp = value
        case OBDPID.intakeTemp.code: live.intakeTemp = value
        case OBDPID.oilTemp.code: live.oilTemp = value
        case OBDPID.manifoldPressure.code: live.boostBar = (value - baroKPa) / 100
        case OBDPID.throttle.code: live.throttle = value
        case OBDPID.moduleVoltage.code: live.voltage = value
        default: break
        }
    }

    // MARK: - Demo

    private func stopDemo() {
        demoTimer?.invalidate()
        demoTimer = nil
        live = LiveData()
        status = .disconnected
    }

    /// Repeating 15 s cycle: a full-throttle pull to about 210 km/h, then coasting back to a stop.
    private func tickDemo() {
        demoTime += 0.1
        let t = demoTime.truncatingRemainder(dividingBy: 15)
        let pulling = t < 10
        let speed = pulling ? min(t * 24, 210) : max(210 - (t - 10) * 42, 0)
        // Rough eight-speed feel: RPM climbs and drops back at each shift.
        let gearProgress = (speed.truncatingRemainder(dividingBy: 35)) / 35

        live.speed = speed
        live.rpm = pulling ? 2500 + gearProgress * 3700 : 750 + speed * 12
        live.throttle = pulling ? 100 : 0
        live.boostBar = pulling ? 0.75 + 0.05 * sin(demoTime * 3) : -0.6
        live.coolantTemp = 94 + 2 * sin(demoTime / 20)
        live.oilTemp = 104 + 3 * sin(demoTime / 30)
        live.intakeTemp = pulling ? 38 : 32
        live.voltage = 14.3
    }
}
