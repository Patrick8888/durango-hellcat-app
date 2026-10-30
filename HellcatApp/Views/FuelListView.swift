import SwiftData
import SwiftUI

struct FuelListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FuelEntry.date, order: .reverse) private var entries: [FuelEntry]
    @State private var showingAdd = false

    var body: some View {
        let consumption = FuelStats.consumption(for: entries)
        NavigationStack {
            List {
                if !entries.isEmpty {
                    Section("Übersicht") {
                        if let average = FuelStats.average(for: entries) {
                            LabeledContent("Ø Verbrauch", value: String(format: "%.1f l/100 km", average))
                        }
                        LabeledContent("Getankt gesamt",
                                       value: String(format: "%.0f l", entries.map(\.liters).reduce(0, +)))
                        LabeledContent("Kosten gesamt",
                                       value: entries.map(\.totalCost).reduce(0, +),
                                       format: .currency(code: appCurrency))
                    }
                }

                Section("Tankstopps") {
                    if entries.isEmpty {
                        Text("Noch keine Tankstopps. Ab dem zweiten vollen Tank wird der Verbrauch berechnet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.1f l", entry.liters) + (entry.fullTank ? "" : " (Teilfüllung)"))
                                    .font(.headline)
                                Text("\(entry.date.formatted(date: .abbreviated, time: .omitted)) · \(entry.mileage.formatted()) km")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(entry.totalCost, format: .currency(code: appCurrency))
                                if let value = consumption[entry.persistentModelID] {
                                    Text(String(format: "%.1f l/100 km", value))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { entries[$0] }.forEach { context.delete($0) }
                    }
                }
            }
            .navigationTitle("Tankbuch")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Tankstopp hinzufügen", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                FuelFormView(lastPrice: entries.first?.pricePerLiter)
            }
        }
    }
}

struct FuelFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let lastPrice: Double?

    @State private var date = Date.now
    @State private var mileage: Int?
    @State private var liters: Double?
    @State private var price: Double?
    @State private var fullTank = true

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Datum", selection: $date)
                TextField("Kilometerstand", value: $mileage, format: .number)
                    .keyboardType(.numberPad)
                TextField("Liter", value: $liters, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Preis pro Liter", value: $price, format: .number)
                    .keyboardType(.decimalPad)
                Toggle("Vollgetankt", isOn: $fullTank)
                if let liters, let price {
                    LabeledContent("Betrag", value: liters * price, format: .currency(code: appCurrency))
                }
            }
            .navigationTitle("Tankstopp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(mileage == nil || liters == nil || price == nil)
                }
            }
            .onAppear {
                if price == nil { price = lastPrice }
            }
        }
    }

    private func save() {
        guard let mileage, let liters, let price else { return }
        context.insert(FuelEntry(date: date, mileage: mileage, liters: liters, pricePerLiter: price, fullTank: fullTank))
        dismiss()
    }
}
