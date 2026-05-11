//
//  LedgerStore.swift
//  Accounting
//

import Combine
import Foundation

@MainActor
final class LedgerStore: ObservableObject {
    @Published private(set) var entries: [LedgerEntry] = []

    private let fileURL: URL
    private let calendar = Calendar.current

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = documents.appendingPathComponent("ledger_entries.json")
        load()
    }

    func add(_ entry: LedgerEntry) {
        entries.insert(entry, at: 0)
        sortEntries()
        save()
    }

    func update(_ entry: LedgerEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        sortEntries()
        save()
    }

    func delete(_ entry: LedgerEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func delete(ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            entries.remove(at: index)
        }
        save()
    }

    func total(for type: EntryType, in range: DateInterval) -> Decimal {
        entries
            .filter { $0.type == type && range.contains($0.date) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func entries(in range: DateInterval) -> [LedgerEntry] {
        entries.filter { range.contains($0.date) }
    }

    var currentMonthRange: DateInterval {
        calendar.dateInterval(of: .month, for: Date())!
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            entries = []
            return
        }

        do {
            entries = try JSONDecoder().decode([LedgerEntry].self, from: data)
            sortEntries()
        } catch {
            entries = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save ledger entries: \(error.localizedDescription)")
        }
    }

    private func sortEntries() {
        entries.sort { $0.date > $1.date }
    }
}
