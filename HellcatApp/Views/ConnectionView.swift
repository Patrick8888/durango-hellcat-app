import SwiftUI

struct ConnectionView: View {
    @Environment(OBDManager.self) private var obd

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    StatusBanner(status: obd.status)
                        .listRowInsets(EdgeInsets())
                    if let info = obd.adapterInfo {
                        LabeledContent("Adapter", value: info)
                    }
                    if obd.isStreaming {
                        Button("Trennen", role: .destructive) { obd.disconnect() }
                    }
                }

                if !obd.isStreaming {
                    Section {
                        if obd.status == .scanning {
                            Button("Suche stoppen") { obd.stopScan() }
                        } else {
                            Button("Nach Adapter suchen") { obd.startScan() }
                        }
                        ForEach(obd.devices) { device in
                            Button {
                                obd.connect(device)
                            } label: {
                                HStack {
                                    Image(systemName: device.looksLikeOBD ? "car.fill" : "dot.radiowaves.left.and.right")
                                    Text(device.name)
                                    Spacer()
                                    Text("\(device.rssi) dBm")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Bluetooth-Adapter")
                    } footer: {
                        Text("Zündung einschalten, Adapter in die OBD-Buchse unter dem Lenkrad stecken. Empfohlen: OBDLink CX (Bluetooth LE).")
                    }

                    Section {
                        Button("Demo-Modus starten") { obd.startDemo() }
                    } footer: {
                        Text("Simuliert Live-Daten, damit du die App ohne Adapter ausprobieren kannst.")
                    }
                }

                if !obd.unsupported.isEmpty {
                    Section("Vom Fahrzeug nicht unterstützt") {
                        Text(obd.unsupported.sorted().map { String(format: "PID 01%02X", Int($0)) }.joined(separator: ", "))
                            .font(.footnote.monospaced())
                    }
                }
            }
            .navigationTitle("Adapter")
        }
    }
}
