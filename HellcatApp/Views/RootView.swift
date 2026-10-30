import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Live", systemImage: "gauge.with.dots.needle.67percent") }
            PerformanceView()
                .tabItem { Label("Performance", systemImage: "stopwatch") }
            MaintenanceListView()
                .tabItem { Label("Wartung", systemImage: "wrench.and.screwdriver") }
            FuelListView()
                .tabItem { Label("Tanken", systemImage: "fuelpump") }
            ConnectionView()
                .tabItem { Label("Adapter", systemImage: "antenna.radiowaves.left.and.right") }
        }
    }
}
