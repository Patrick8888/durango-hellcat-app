import CoreBluetooth
import Foundation

/// Bluetooth LE link to an ELM327-compatible adapter such as the OBDLink CX.
///
/// Adapters use different vendor UUIDs, so instead of hard-coding them we pick the
/// first service that offers both a notify and a write characteristic.
final class BLEConnection: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum State: Equatable {
        case bluetoothOff
        case idle
        case scanning
        case connecting
        case connected
        case failed(String)
    }

    var onStateChange: ((State) -> Void)?
    var onDiscover: ((CBPeripheral, Int) -> Void)?
    /// Called with each complete adapter response (everything before the `>` prompt).
    var onResponse: ((String) -> Void)?

    private(set) var state: State = .idle {
        didSet { if state != oldValue { onStateChange?(state) } }
    }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var buffer = ""

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else {
            state = .bluetoothOff
            return
        }
        state = .scanning
        central.scanForPeripherals(withServices: nil)
    }

    func stopScan() {
        central.stopScan()
        if state == .scanning { state = .idle }
    }

    func connect(_ peripheral: CBPeripheral) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        state = .connecting
        central.connect(peripheral)
    }

    func disconnect() {
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
    }

    func send(_ command: String) {
        guard let peripheral, let characteristic = writeCharacteristic,
              let data = (command + "\r").data(using: .ascii) else { return }
        let type: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: characteristic, type: type)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state == .poweredOn ? .idle : .bluetoothOff
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Unnamed devices are almost never OBD adapters and would flood the list.
        guard peripheral.name != nil || advertisementData[CBAdvertisementDataLocalNameKey] != nil else { return }
        onDiscover?(peripheral, RSSI.intValue)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .failed(error?.localizedDescription ?? "Verbindung fehlgeschlagen")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        writeCharacteristic = nil
        buffer = ""
        state = .idle
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard writeCharacteristic == nil else { return }
        let characteristics = service.characteristics ?? []
        let notify = characteristics.first { $0.properties.contains(.notify) || $0.properties.contains(.indicate) }
        let write = characteristics.first { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }
        guard let notify, let write else { return }

        writeCharacteristic = write
        peripheral.setNotifyValue(true, for: notify)
        state = .connected
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let text = String(data: data, encoding: .ascii) else { return }
        buffer += text
        while let prompt = buffer.firstIndex(of: ">") {
            let response = String(buffer[..<prompt]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeSubrange(...prompt)
            onResponse?(response)
        }
    }
}
