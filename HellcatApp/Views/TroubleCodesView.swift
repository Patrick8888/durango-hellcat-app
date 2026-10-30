import SwiftUI

struct TroubleCodesView: View {
    @Environment(OBDManager.self) private var obd
    @Environment(\.dismiss) private var dismiss
    @State private var codes: [String]?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    HStack {
                        ProgressView()
                        Text("Lese Fehlerspeicher…")
                    }
                } else if let codes {
                    if codes.isEmpty {
                        Label("Keine gespeicherten Fehlercodes", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        ForEach(codes, id: \.self) { code in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(code)
                                    .font(.headline.monospaced())
                                Text(TroubleCodeInfo.description(for: code))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Label("Keine Antwort vom Fahrzeug", systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }

                Section {
                    Text("Fehlercodes löschen ist bewusst nicht eingebaut: Das Secure Gateway im Durango blockiert das ohne freigeschaltetes Diagnosegerät.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Fehlercodes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Neu lesen", action: load)
                        .disabled(loading)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        loading = true
        obd.readTroubleCodes { result in
            codes = result
            loading = false
        }
    }
}

/// Plain-language hints for the generic codes that come up most on the 6.2 supercharged HEMI.
enum TroubleCodeInfo {
    static let known: [String: String] = [
        "P0300": "Zündaussetzer, mehrere Zylinder",
        "P0301": "Zündaussetzer Zylinder 1",
        "P0302": "Zündaussetzer Zylinder 2",
        "P0303": "Zündaussetzer Zylinder 3",
        "P0304": "Zündaussetzer Zylinder 4",
        "P0305": "Zündaussetzer Zylinder 5",
        "P0306": "Zündaussetzer Zylinder 6",
        "P0307": "Zündaussetzer Zylinder 7",
        "P0308": "Zündaussetzer Zylinder 8",
        "P0420": "Katalysator Wirkungsgrad zu niedrig (Bank 1)",
        "P0430": "Katalysator Wirkungsgrad zu niedrig (Bank 2)",
        "P0456": "Tankentlüftung: sehr kleines Leck (oft Tankdeckel)",
        "P0457": "Tankentlüftung: Leck, Tankdeckel lose",
        "P0128": "Kühlmitteltemperatur unter Sollwert (Thermostat)",
        "P0171": "Gemisch zu mager (Bank 1)",
        "P0174": "Gemisch zu mager (Bank 2)",
        "P0234": "Ladedruck zu hoch",
        "P0299": "Ladedruck zu niedrig",
        "P0562": "Bordspannung zu niedrig",
        "P0700": "Getriebesteuerung meldet Fehler",
    ]

    static func description(for code: String) -> String {
        if let text = known[code] { return text }
        switch code.first {
        case "P": return "Antrieb (Motor/Getriebe)"
        case "C": return "Fahrwerk"
        case "B": return "Karosserie"
        case "U": return "Kommunikation zwischen Steuergeräten"
        default: return "Unbekannt"
        }
    }
}
