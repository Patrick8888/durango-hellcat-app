import Foundation
import SwiftData

@Model
final class FuelEntry {
    var date: Date
    var mileage: Int
    var liters: Double
    var pricePerLiter: Double
    var fullTank: Bool

    init(date: Date = .now, mileage: Int, liters: Double, pricePerLiter: Double, fullTank: Bool = true) {
        self.date = date
        self.mileage = mileage
        self.liters = liters
        self.pricePerLiter = pricePerLiter
        self.fullTank = fullTank
    }

    var totalCost: Double { liters * pricePerLiter }
}

enum FuelStats {
    /// Consumption in l/100 km for each full-tank entry, measured since the previous full tank.
    static func consumption(for entries: [FuelEntry]) -> [PersistentIdentifier: Double] {
        let sorted = entries.sorted { $0.mileage < $1.mileage }
        var result: [PersistentIdentifier: Double] = [:]
        var lastFullMileage: Int?
        var litersSinceFull = 0.0

        for entry in sorted {
            litersSinceFull += entry.liters
            guard entry.fullTank else { continue }
            if let last = lastFullMileage, entry.mileage > last {
                result[entry.persistentModelID] = litersSinceFull / Double(entry.mileage - last) * 100
            }
            lastFullMileage = entry.mileage
            litersSinceFull = 0
        }
        return result
    }

    static func average(for entries: [FuelEntry]) -> Double? {
        let values = Array(consumption(for: entries).values)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
