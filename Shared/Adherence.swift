import SwiftUI

// Per-day adherence, shared by the History calendar and the calendar widget.
struct DayAdherence {
    let total: Int
    let taken: Int

    var ratio: Double { total == 0 ? 0 : Double(taken) / Double(total) }

    var color: Color {
        guard total > 0 else { return .clear }
        switch ratio {
        case 1.0: return Theme.taken // green
        case 0.5 ..< 1.0: return Theme.snoozed // gold
        default: return Theme.missed // oxblood
        }
    }

    // Counts only doses that are due (<= now) or already acted on; future,
    // un-acted doses are neutral so they don't read as "0% adherent".
    static func compute(prescriptions: [Prescription], logs: [DoseLog],
                        day: Date, now: Date) -> DayAdherence
    {
        let cal = Calendar.current
        let dayLogs = logs.filter { cal.isDate($0.scheduledDate, inSameDayAs: day) }
        var total = 0, taken = 0
        for prescription in prescriptions {
            for date in ScheduleService.occurrences(for: prescription, on: day) {
                let logged = dayLogs.first {
                    $0.prescriptionId == prescription.id &&
                        cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute)
                }
                guard logged != nil || date <= now else { continue }
                total += 1
                if (logged?.status ?? .missed) == .taken { taken += 1 }
            }
        }
        return DayAdherence(total: total, taken: taken)
    }
}
