import SwiftData
import SwiftUI

struct PerformanceView: View {
    @Environment(OBDManager.self) private var obd
    @Environment(\.modelContext) private var context
    @Query(sort: \PerformanceRun.date, order: .reverse) private var runs: [PerformanceRun]
    @State private var timer = PerformanceTimer()
    @State private var savedFinish = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Messung", selection: $timer.kind) {
                        ForEach(RunKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(timer.phase != .idle && !isFinished)

                    VStack(spacing: 8) {
                        Text(display)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(hint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if timer.phase != .idle {
                            Text("\(Int(timer.currentSpeed)) km/h · Quelle: \(timer.source)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                    if timer.phase == .idle || isFinished {
                        Button {
                            savedFinish = false
                            timer.arm { obd.isStreaming ? obd.live.speed : nil }
                        } label: {
                            Label("Messung starten", systemImage: "flag.checkered")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Abbrechen", role: .cancel) { timer.cancel() }
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Nur auf abgesperrter Strecke messen. Mit verbundenem Adapter wird das OBD-Tempo verwendet, sonst GPS (ungenauer).")
                }

                ForEach(RunKind.allCases) { kind in
                    let kindRuns = runs.filter { $0.kind == kind }
                    if !kindRuns.isEmpty {
                        Section(kind.rawValue) {
                            if let best = kindRuns.min(by: { $0.seconds < $1.seconds }) {
                                LabeledContent("Bestzeit", value: String(format: "%.2f s", best.seconds))
                                    .fontWeight(.semibold)
                            }
                            ForEach(kindRuns) { run in
                                LabeledContent {
                                    Text(String(format: "%.2f s", run.seconds))
                                        .monospacedDigit()
                                } label: {
                                    Text(run.date.formatted(date: .abbreviated, time: .shortened))
                                    Text(run.source)
                                }
                            }
                            .onDelete { offsets in
                                offsets.map { kindRuns[$0] }.forEach { context.delete($0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Performance")
            .onChange(of: timer.phase) { _, phase in
                if case .finished(let seconds) = phase, !savedFinish {
                    savedFinish = true
                    context.insert(PerformanceRun(kind: timer.kind, seconds: seconds, source: timer.source))
                }
            }
        }
    }

    private var isFinished: Bool {
        if case .finished = timer.phase { return true }
        return false
    }

    private var display: String {
        switch timer.phase {
        case .finished(let seconds): String(format: "%.2f s", seconds)
        case .running: "läuft"
        default: "–"
        }
    }

    private var hint: String {
        switch timer.phase {
        case .idle: "Wähle eine Messung und tippe auf Start."
        case .waitingForStart:
            timer.kind.startSpeed == 0 ? "Bitte anhalten." : "Unter \(Int(timer.kind.startSpeed)) km/h fahren."
        case .armed:
            timer.kind.startSpeed == 0 ? "Bereit. Die Zeit startet beim Losfahren."
                                       : "Bereit. Die Zeit startet bei \(Int(timer.kind.startSpeed)) km/h."
        case .running: "Bis \(Int(timer.kind.targetSpeed)) km/h"
        case .finished: "Gespeichert."
        }
    }
}
