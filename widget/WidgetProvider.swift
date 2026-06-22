import Foundation
import SwiftData
import WidgetKit

struct WidgetProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> DoseEntry {
        .placeholder()
    }

    func snapshot(for configuration: PrescriptionSelectionIntent, in _: Context) async -> DoseEntry {
        await makeEntry(for: configuration)
    }

    func timeline(for configuration: PrescriptionSelectionIntent, in _: Context) async -> Timeline<DoseEntry> {
        let entry = await makeEntry(for: configuration)

        // Refresh at each remaining dose time today, and at the next midnight.
        let cal = Calendar.current
        var refreshDates = entry.items
            .map(\.scheduledDate)
            .filter { $0 > entry.date }
        if let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: entry.date)) {
            refreshDates.append(midnight)
        }
        let next = refreshDates.min() ?? cal.date(byAdding: .hour, value: 1, to: entry.date)!

        return Timeline(entries: [entry], policy: .after(next))
    }

    // MARK: - Entry construction

    @MainActor
    private func makeEntry(for configuration: PrescriptionSelectionIntent) async -> DoseEntry {
        let now = Date()
        guard let container = try? ModelContainerFactory.makeSharedContainer() else {
            return DoseEntry(date: now, items: [], streak: 0)
        }
        let context = ModelContext(container)

        let prescriptions = (try? context.fetch(
            FetchDescriptor<Prescription>(predicate: #Predicate { !$0.isArchived })
        )) ?? []
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []

        // Narrow to a configured prescription only if it still exists; otherwise
        // (no selection, or a stale/deleted one) show all of today's doses.
        let selected: [Prescription]
        if let id = configuration.prescription?.id,
           prescriptions.contains(where: { $0.id == id })
        {
            selected = prescriptions.filter { $0.id == id }
        } else {
            selected = prescriptions
        }

        let cal = Calendar.current
        var items: [DoseItem] = []
        for prescription in selected {
            for date in ScheduleService.occurrences(for: prescription, on: now) {
                let log = logs.first {
                    $0.prescriptionId == prescription.id &&
                        cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute)
                }
                let status = log?.status ?? (date <= now ? .missed : .pending)
                items.append(DoseItem(
                    prescriptionId: prescription.id,
                    name: prescription.name,
                    colorHex: prescription.color,
                    scheduledDate: date,
                    status: status
                ))
            }
        }
        items.sort { $0.scheduledDate < $1.scheduledDate }

        return DoseEntry(
            date: now,
            items: items,
            streak: SharedDefaults.shared.streakCache
        )
    }
}
