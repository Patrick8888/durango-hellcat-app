import SwiftUI

struct DashboardView: View {
    @Environment(OBDManager.self) private var obd
    @State private var showingCodes = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    StatusBanner(status: obd.status)

                    RPMGauge(rpm: obd.live.rpm)
                        .frame(height: 220)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ValueTile(title: "Tempo", value: obd.live.speed, unit: "km/h", format: "%.0f")
                        ValueTile(title: "Ladedruck", value: obd.live.boostBar, unit: "bar", format: "%+.2f")
                        ValueTile(title: "Gaspedal", value: obd.live.throttle, unit: "%", format: "%.0f")
                        ValueTile(title: "Kühlmittel", value: obd.live.coolantTemp, unit: "°C", format: "%.0f",
                                  warning: { $0 > 110 })
                        ValueTile(title: "Öl", value: obd.live.oilTemp, unit: "°C", format: "%.0f",
                                  warning: { $0 > 130 }, unsupported: obd.unsupported.contains(OBDPID.oilTemp.code))
                        ValueTile(title: "Ansaugluft", value: obd.live.intakeTemp, unit: "°C", format: "%.0f",
                                  warning: { $0 > 60 })
                        ValueTile(title: "Batterie", value: obd.live.voltage, unit: "V", format: "%.1f",
                                  warning: { $0 < 12.0 })
                    }

                    WarmUpHint(oilTemp: obd.live.oilTemp, coolantTemp: obd.live.coolantTemp)
                }
                .padding()
            }
            .navigationTitle("Durango SRT Hellcat")
            .toolbar {
                Button {
                    showingCodes = true
                } label: {
                    Label("Fehlercodes", systemImage: "exclamationmark.triangle")
                }
                .disabled(!obd.isStreaming)
            }
            .sheet(isPresented: $showingCodes) {
                TroubleCodesView()
            }
        }
    }
}

struct StatusBanner: View {
    let status: OBDManager.Status

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(status.label)
                .font(.subheadline)
            Spacer()
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var color: Color {
        switch status {
        case .live: .green
        case .demo: .orange
        case .failed, .bluetoothOff: .red
        default: .gray
        }
    }
}

struct RPMGauge: View {
    let rpm: Double?
    private let maxRPM = 7000.0
    private let redline = 6200.0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(.quaternary, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: redline / maxRPM * 0.75, to: 0.75)
                .stroke(Color.hellcatRed.opacity(0.35), style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: min((rpm ?? 0) / maxRPM, 1) * 0.75)
                .stroke((rpm ?? 0) >= redline ? Color.hellcatRed : Color.primary,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
                .animation(.linear(duration: 0.15), value: rpm)
            VStack(spacing: 2) {
                Text(rpm.map { String(format: "%.0f", $0) } ?? "–")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("U/min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }
}

struct ValueTile: View {
    let title: String
    let value: Double?
    let unit: String
    let format: String
    var warning: (Double) -> Bool = { _ in false }
    var unsupported = false

    var body: some View {
        let isWarning = value.map(warning) ?? false
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(unsupported ? "n. v." : value.map { String(format: format, $0) } ?? "–")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(isWarning ? Color.hellcatRed.opacity(0.3) : Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Full boost on a cold engine wears it fast; this tells you when it is ready.
struct WarmUpHint: View {
    let oilTemp: Double?
    let coolantTemp: Double?

    var body: some View {
        if let temp = oilTemp ?? coolantTemp {
            let ready = oilTemp != nil ? temp >= 80 : temp >= 85
            Label(ready ? "Motor warm, bereit für Volllast"
                        : "Motor noch kalt, bitte schonend fahren",
                  systemImage: ready ? "checkmark.seal.fill" : "snowflake")
                .font(.subheadline)
                .foregroundStyle(ready ? .green : .orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
