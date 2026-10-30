import SwiftData
import SwiftUI

struct MaintenanceListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MaintenanceEntry.date, order: .reverse) private var entries: [MaintenanceEntry]
    @State private var showingAdd = false

    private var currentMileage: Int? {
        entries.map(\.mileage).max()
    }

    /// The latest entry per category that has a next due date or mileage.
    private var upcoming: [MaintenanceEntry] {
        var seen = Set<String>()
        return entries.filter { entry in
            guard entry.nextDueDate != nil || entry.nextDueMileage != nil,
                  !seen.contains(entry.categoryRaw) else { return false }
            seen.insert(entry.categoryRaw)
            return true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !upcoming.isEmpty {
                    Section("Als Nächstes fällig") {
                        ForEach(upcoming) { entry in
                            DueRow(entry: entry, currentMileage: currentMileage)
                        }
                    }
                }

                Section("Verlauf") {
                    if entries.isEmpty {
                        Text("Noch keine Einträge. Tippe auf +, um z. B. den letzten Ölwechsel einzutragen.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(entries) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: entry.category.symbol)
                                .foregroundStyle(Color.hellcatRed)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayTitle)
                                    .font(.headline)
                                Text("\(entry.date.formatted(date: .abbreviated, time: .omitted)) · \(entry.mileage.formatted()) km")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !entry.notes.isEmpty {
                                    Text(entry.notes)
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            if entry.cost > 0 {
                                Text(entry.cost, format: .currency(code: appCurrency))
                                    .font(.subheadline)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { entries[$0] }.forEach { context.delete($0) }
                    }
                }

                if !entries.isEmpty {
                    Section {
                        LabeledContent("Gesamtkosten",
                                       value: entries.map(\.cost).reduce(0, +),
                                       format: .currency(code: appCurrency))
                    }
                }
            }
            .navigationTitle("Wartungsheft")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Eintrag hinzufügen", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                MaintenanceFormView(suggestedMileage: currentMileage)
            }
        }
    }
}

private struct DueRow: View {
    let entry: MaintenanceEntry
    let currentMileage: Int?

    var body: some View {
        let overdue = isOverdue
        HStack {
            Image(systemName: entry.category.symbol)
                .foregroundStyle(overdue ? .red : .orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category.rawValue)
                    .font(.headline)
                Text(dueText)
                    .font(.caption)
                    .foregroundStyle(overdue ? .red : .secondary)
            }
        }
    }

    private var isOverdue: Bool {
        if let date = entry.nextDueDate, date < .now { return true }
        if let due = entry.nextDueMileage, let current = currentMileage, current >= due { return true }
        return false
    }

    private var dueText: String {
        var parts: [String] = []
        if let due = entry.nextDueMileage {
            var text = "bei \(due.formatted()) km"
            if let current = currentMileage {
                text += due > current ? " (noch \((due - current).formatted()) km)" : " (überfällig)"
            }
            parts.append(text)
        }
        if let date = entry.nextDueDate {
            parts.append("bis \(date.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.joined(separator: " oder ")
    }
}

struct MaintenanceFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let suggestedMileage: Int?

    @State private var category: MaintenanceCategory = .oilChange
    @State private var title = ""
    @State private var date = Date.now
    @State private var mileage: Int?
    @State private var cost: Double?
    @State private var notes = ""
    @State private var remind = true
    @State private var intervalKm: Int? = 10_000
    @State private var intervalMonths = 12

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $category) {
                        ForEach(MaintenanceCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.symbol).tag(category)
                        }
                    }
                    TextField("Titel (optional)", text: $title)
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                    TextField("Kilometerstand", value: $mileage, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Kosten", value: $cost, format: .number)
                        .keyboardType(.decimalPad)
                }

                Section("Notizen") {
                    TextField("z. B. Öl Pennzoil Ultra Platinum 0W-40, Filter Mopar", text: $notes, axis: .vertical)
                }

                Section("Erinnerung") {
                    Toggle("Nächste Fälligkeit merken", isOn: $remind)
                    if remind {
                        TextField("Intervall in km", value: $intervalKm, format: .number)
                            .keyboardType(.numberPad)
                        Stepper("Spätestens nach \(intervalMonths) Monaten", value: $intervalMonths, in: 1...48)
                    }
                }
            }
            .navigationTitle("Neuer Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(mileage == nil)
                }
            }
            .onAppear {
                if mileage == nil { mileage = suggestedMileage }
                applyDefaultInterval()
            }
            .onChange(of: category) { applyDefaultInterval() }
        }
    }

    /// Rough intervals for the supercharged HEMI; adjust to the owner's manual.
    private func applyDefaultInterval() {
        switch category {
        case .oilChange: intervalKm = 10_000; intervalMonths = 12
        case .sparkPlugs: intervalKm = 48_000; intervalMonths = 48
        case .brakes: intervalKm = 30_000; intervalMonths = 24
        case .tires: intervalKm = 20_000; intervalMonths = 36
        case .superchargerBelt: intervalKm = 80_000; intervalMonths = 48
        case .fluids: intervalKm = nil; intervalMonths = 24
        case .service, .other: intervalKm = nil; intervalMonths = 12
        }
    }

    private func save() {
        guard let mileage else { return }
        let entry = MaintenanceEntry(
            date: date,
            mileage: mileage,
            category: category,
            title: title,
            notes: notes,
            cost: cost ?? 0,
            nextDueMileage: remind ? intervalKm.map { mileage + $0 } : nil,
            nextDueDate: remind ? Calendar.current.date(byAdding: .month, value: intervalMonths, to: date) : nil
        )
        context.insert(entry)
        dismiss()
    }
}
