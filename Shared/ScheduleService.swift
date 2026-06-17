import Foundation

enum ScheduleService {
    // All scheduled dates for a prescription on a given calendar day
    static func occurrences(for prescription: Prescription, on day: Date) -> [Date] {
        guard isScheduled(prescription, on: day) else { return [] }
        let occurrence = day.settingTime(from: prescription.scheduledTime)
        return [occurrence]
    }

    // All scheduled dates between start and end (inclusive of both endpoints' days)
    static func occurrences(
        for prescription: Prescription,
        from start: Date,
        through end: Date
    ) -> [Date] {
        let cal = Calendar.current
        var results: [Date] = []
        var current = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)

        while current <= endDay {
            results.append(contentsOf: occurrences(for: prescription, on: current))
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return results
    }

    // Whether a prescription has a scheduled occurrence on this calendar day
    static func isScheduled(_ prescription: Prescription, on day: Date) -> Bool {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)

        // Don't schedule before the prescription was created
        if dayStart < cal.startOfDay(for: prescription.createdAt) {
            return false
        }
        // Archived prescriptions stop generating occurrences after their archive day.
        // (Past logs from when it was active are preserved and still shown in history.)
        if let archivedAt = prescription.archivedAt,
           dayStart > cal.startOfDay(for: archivedAt) {
            return false
        }
        switch prescription.frequency {
        case .daily:
            return true
        case .weekly(let days):
            let weekday = Calendar.current.component(.weekday, from: day)
            return days.contains(Weekday(rawValue: weekday) ?? .sunday)
        }
    }
}
