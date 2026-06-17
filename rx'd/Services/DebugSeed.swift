#if DEBUG
import Foundation
import SwiftData

// Launch with `--seed` (xcrun simctl launch <device> codes.ruben.rx-d --seed)
// to populate sample data and skip onboarding. DEBUG builds only.
enum DebugSeed {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--seed")
    }

    @MainActor
    static func run(context: ModelContext) {
        // Idempotent: wipe existing sample data first.
        if let existing = try? context.fetch(FetchDescriptor<Prescription>()) {
            for p in existing { context.delete(p) }
        }
        if let logs = try? context.fetch(FetchDescriptor<DoseLog>()) {
            for l in logs { context.delete(l) }
        }

        let cal = Calendar.current
        let now = Date()

        // Two daily prescriptions created 5 days ago, plus a weekday-only one.
        let createdAt = cal.date(byAdding: .day, value: -5, to: now)!

        let morning = Prescription(
            name: "Morning Vitamins",
            scheduledTime: cal.date(bySettingHour: 8, minute: 0, second: 0, of: now)!,
            frequency: .daily,
            color: "#5B8DEF"
        )
        morning.createdAt = createdAt

        let evening = Prescription(
            name: "Evening Magnesium",
            scheduledTime: cal.date(bySettingHour: 21, minute: 0, second: 0, of: now)!,
            frequency: .daily,
            color: "#CC5DE8"
        )
        evening.createdAt = createdAt

        let weekday = Prescription(
            name: "Weekday Probiotic",
            scheduledTime: cal.date(bySettingHour: 12, minute: 30, second: 0, of: now)!,
            frequency: .weekly(days: [.monday, .tuesday, .wednesday, .thursday, .friday]),
            color: "#20C997"
        )
        weekday.createdAt = createdAt

        let archived = Prescription(
            name: "Old Antibiotic",
            scheduledTime: cal.date(bySettingHour: 9, minute: 0, second: 0, of: now)!,
            frequency: .daily,
            color: "#FF6B6B"
        )
        archived.createdAt = cal.date(byAdding: .day, value: -20, to: now)!
        archived.isArchived = true
        archived.archivedAt = cal.date(byAdding: .day, value: -10, to: now)!

        context.insert(morning)
        context.insert(evening)
        context.insert(weekday)
        context.insert(archived)

        // History: mark the morning vitamin taken on each of the past 4 days (a streak),
        // and leave the evening magnesium mixed (some taken, some missed).
        for dayOffset in 1...4 {
            let day = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            for date in ScheduleService.occurrences(for: morning, on: day) {
                context.insert(DoseLog(
                    prescriptionId: morning.id,
                    scheduledDate: date,
                    status: .taken,
                    completedAt: date
                ))
            }
            // Evening: taken on even offsets, missed on odd → partial adherence days.
            for date in ScheduleService.occurrences(for: evening, on: day) {
                context.insert(DoseLog(
                    prescriptionId: evening.id,
                    scheduledDate: date,
                    status: dayOffset % 2 == 0 ? .taken : .missed,
                    completedAt: dayOffset % 2 == 0 ? date : nil
                ))
            }
        }

        // Pretend the morning vitamin was imported from Apple Health (badge demo).
        morning.healthConceptID = "debug-health-concept"

        // Today: mark the 8am vitamin already taken so Today shows a green pill.
        // Flagged isFromHealth so the "Apple Health" badge shows.
        if let todayMorning = ScheduleService.occurrences(for: morning, on: now).first {
            context.insert(DoseLog(
                prescriptionId: morning.id,
                scheduledDate: todayMorning,
                status: .taken,
                completedAt: now,
                isFromHealth: true
            ))
        }
        // --all-done: also mark today's evening dose taken to show the celebration state.
        if ProcessInfo.processInfo.arguments.contains("--all-done"),
           let todayEvening = ScheduleService.occurrences(for: evening, on: now).first {
            context.insert(DoseLog(
                prescriptionId: evening.id,
                scheduledDate: todayEvening,
                status: .taken,
                completedAt: now
            ))
        }

        try? context.save()

        let prescriptions = (try? context.fetch(FetchDescriptor<Prescription>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
        _ = StreakService.computeAndCache(prescriptions: prescriptions, logs: logs)
        SharedDefaults.shared.hasCompletedOnboarding = true
    }
}
#endif
