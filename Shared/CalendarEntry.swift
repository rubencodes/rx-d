import Foundation
import WidgetKit

struct CalendarEntry: TimelineEntry {
    let date: Date
    let monthStart: Date
    let days: [CalendarDay]

    static func placeholder() -> CalendarEntry {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let count = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let days = (0 ..< count).compactMap { offset -> CalendarDay? in
            guard let d = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return CalendarDay(date: d, total: offset % 3 == 0 ? 2 : 0, taken: offset % 3 == 0 ? 1 : 0)
        }
        return CalendarEntry(date: Date(), monthStart: start, days: days)
    }
}
