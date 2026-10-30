import SwiftUI
import SwiftData

@main
struct HellcatApp: App {
    @State private var obd = OBDManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(obd)
                .tint(.hellcatRed)
        }
        .modelContainer(for: [MaintenanceEntry.self, FuelEntry.self, PerformanceRun.self])
    }
}

extension Color {
    static let hellcatRed = Color(red: 0.85, green: 0.0, blue: 0.0)
}

/// Currency of the phone's region, used for costs in the maintenance and fuel logs.
let appCurrency = Locale.current.currency?.identifier ?? "EUR"
