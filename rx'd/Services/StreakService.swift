import Foundation

enum StreakService {
    // Computes consecutive-day streak and caches result in SharedDefaults.
    // A day counts toward the streak only if all scheduled doses were taken.
    // Days with no scheduled doses are neutral (neither extend nor break the streak).
    static func computeAndCache(prescriptions: [Prescription], logs: [DoseLog]) -> Int {
        let streak = compute(prescriptions: prescriptions, logs: logs)
        SharedDefaults.shared.streakCache = streak
        SharedDefaults.shared.streakLastComputedDate = Date()
        return streak
    }

    static func compute(prescriptions: [Prescription], logs: [DoseLog]) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var streak = 0
        var checking = cal.date(byAdding: .day, value: -1, to: today)! // start from yesterday

        while true {
            let dayPrescriptions = prescriptions.filter {
                !$0.isArchived && ScheduleService.isScheduled($0, on: checking)
            }
            guard !dayPrescriptions.isEmpty else {
                // No doses this day — neutral, keep walking back
                guard let prev = cal.date(byAdding: .day, value: -1, to: checking) else { break }
                // Avoid infinite loop: stop at the earliest prescription creation date
                let earliest = prescriptions.compactMap { $0.createdAt }.min() ?? checking
                if checking < cal.startOfDay(for: earliest) { break }
                checking = prev
                continue
            }

            let dayLogs = logs.filter { cal.isDate($0.scheduledDate, inSameDayAs: checking) }
            let allTaken = dayPrescriptions.allSatisfy { prescription in
                ScheduleService.occurrences(for: prescription, on: checking).allSatisfy { date in
                    dayLogs.contains {
                        $0.prescriptionId == prescription.id &&
                            cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute) &&
                            $0.status == .taken
                    }
                }
            }

            guard allTaken else { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: checking) else { break }
            checking = prev
        }
        return streak
    }
}
