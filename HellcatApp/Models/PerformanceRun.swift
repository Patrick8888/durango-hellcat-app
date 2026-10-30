import Foundation
import SwiftData

enum RunKind: String, CaseIterable, Identifiable {
    case zeroTo100 = "0–100 km/h"
    case zeroTo200 = "0–200 km/h"
    case hundredTo200 = "100–200 km/h"

    var id: String { rawValue }

    var startSpeed: Double {
        switch self {
        case .zeroTo100, .zeroTo200: 0
        case .hundredTo200: 100
        }
    }

    var targetSpeed: Double {
        switch self {
        case .zeroTo100: 100
        case .zeroTo200, .hundredTo200: 200
        }
    }
}

@Model
final class PerformanceRun {
    var date: Date
    var kindRaw: String
    var seconds: Double
    /// "OBD" or "GPS", so results from different speed sources can be told apart.
    var source: String

    init(date: Date = .now, kind: RunKind, seconds: Double, source: String) {
        self.date = date
        self.kindRaw = kind.rawValue
        self.seconds = seconds
        self.source = source
    }

    var kind: RunKind { RunKind(rawValue: kindRaw) ?? .zeroTo100 }
}
