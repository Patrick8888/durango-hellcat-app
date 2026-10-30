import Foundation
import SwiftData

enum MaintenanceCategory: String, CaseIterable, Identifiable {
    case oilChange = "Ölwechsel"
    case tires = "Reifen"
    case brakes = "Bremsen"
    case service = "Inspektion"
    case sparkPlugs = "Zündkerzen"
    case superchargerBelt = "Kompressor-Riemen"
    case fluids = "Flüssigkeiten"
    case other = "Sonstiges"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .oilChange: "drop.fill"
        case .tires: "circle.circle"
        case .brakes: "exclamationmark.brakesignal"
        case .service: "wrench.and.screwdriver.fill"
        case .sparkPlugs: "bolt.fill"
        case .superchargerBelt: "fanblades.fill"
        case .fluids: "thermometer.medium"
        case .other: "square.and.pencil"
        }
    }
}

@Model
final class MaintenanceEntry {
    var date: Date
    var mileage: Int
    var categoryRaw: String
    var title: String
    var notes: String
    var cost: Double
    var nextDueMileage: Int?
    var nextDueDate: Date?

    init(date: Date = .now, mileage: Int, category: MaintenanceCategory, title: String = "",
         notes: String = "", cost: Double = 0, nextDueMileage: Int? = nil, nextDueDate: Date? = nil) {
        self.date = date
        self.mileage = mileage
        self.categoryRaw = category.rawValue
        self.title = title
        self.notes = notes
        self.cost = cost
        self.nextDueMileage = nextDueMileage
        self.nextDueDate = nextDueDate
    }

    var category: MaintenanceCategory {
        MaintenanceCategory(rawValue: categoryRaw) ?? .other
    }

    var displayTitle: String {
        title.isEmpty ? category.rawValue : title
    }
}
