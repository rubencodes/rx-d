import Foundation
import SwiftData
import WidgetKit

struct CalendarProvider: TimelineProvider {
    func placeholder(in _: Context) -> CalendarEntry { .placeholder() }

    func getSnapshot(in _: Context, completion: @escaping (CalendarEntry) -> Void) {
        Task { @MainActor in completion(makeEntry()) }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        Task { @MainActor in
            let entry = makeEntry()
            let cal = Calendar.current
            // Refresh at the next midnight (new day / month rollover).
            let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: entry.date))
                ?? entry.date.addingTimeInterval(3600)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    @MainActor
    private func makeEntry() -> CalendarEntry {
        let now = Date()
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        guard let container = try? ModelContainerFactory.makeSharedContainer() else {
            return CalendarEntry(date: now, monthStart: monthStart, days: [])
        }
        let ctx = ModelContext(container)
        let prescriptions = (try? ctx.fetch(FetchDescriptor<Prescription>())) ?? []
        let logs = (try? ctx.fetch(FetchDescriptor<DoseLog>())) ?? []

        let count = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let days: [CalendarDay] = (0 ..< count).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: monthStart) else { return nil }
            let a = DayAdherence.compute(prescriptions: prescriptions, logs: logs, day: day, now: now)
            return CalendarDay(date: day, total: a.total, taken: a.taken)
        }
        return CalendarEntry(date: now, monthStart: monthStart, days: days)
    }
}
