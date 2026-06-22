import Foundation
import UserNotifications

enum NotificationService {
    static let maxPending = 60 // keep 4 slots free for snooze notifications
    static let daysAhead = 7
    // Cap for the "repeat until done" follow-up series, per occurrence. The OS limits
    // total pending requests (see maxPending), so an unbounded "every hour forever"
    // isn't possible — we schedule this many nudges and cancel them when the dose is taken.
    static let maxRepeatFollowUps = 4

    // Re-register all notification categories. Call at launch.
    static func registerCategories() {
        let done = UNNotificationAction(
            identifier: "DONE",
            title: "Mark Done",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 30 min",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "DOSE_REMINDER",
            actions: [done, snooze],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // Cancel all pending notifications and reschedule for all active prescriptions.
    //
    // `logs` lets us skip occurrences the user has already taken — otherwise a taken
    // dose whose follow-up time is still in the future would get its "Don't forget!"
    // reminder re-scheduled on every reschedule pass (e.g. each time the app becomes
    // active), firing even though the dose is done.
    static func rescheduleAll(prescriptions: [Prescription], logs: [DoseLog] = []) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var scheduled = 0

        // Index taken doses by prescription so we can skip them while scheduling.
        let takenLogs = logs.filter { $0.status == .taken }

        outer: for dayOffset in 0 ..< daysAhead {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            for prescription in prescriptions where !prescription.isArchived {
                let occurrences = ScheduleService.occurrences(for: prescription, on: day)
                for date in occurrences {
                    if scheduled >= maxPending { break outer }
                    // Don't (re)schedule reminders for a dose that's already been taken.
                    let alreadyTaken = takenLogs.contains {
                        $0.prescriptionId == prescription.id &&
                            cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute)
                    }
                    if alreadyTaken { continue }
                    let added = await schedule(
                        prescription: prescription, at: date,
                        budget: maxPending - scheduled, center: center
                    )
                    scheduled += added
                }
            }
        }
    }

    // Cancel every pending reminder for a single occurrence — the primary and the
    // whole follow-up series (one-shot or "repeat until done"). Used when a dose is
    // marked taken from anywhere (notification DONE, widget intent, in-app tap/swipe,
    // Control Center confirm). Matches by id prefix so it covers any number of repeats.
    static func cancelOccurrence(prescriptionId: UUID, scheduledDate: Date) {
        let prefix = "\(prescriptionId)-\(scheduledDate.isoDateString)-\(scheduledDate.hhmmString)-"
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    static func cancelNotifications(for prescription: Prescription) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(prescription.id.uuidString) }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Private

    // Schedules the primary reminder plus its follow-up(s) for one occurrence, without
    // exceeding `budget` pending requests. Returns how many it actually added.
    @discardableResult
    private static func schedule(
        prescription: Prescription,
        at date: Date,
        budget: Int,
        center: UNUserNotificationCenter
    ) async -> Int {
        guard budget > 0 else { return 0 }
        let dateStr = date.isoDateString
        let timeStr = date.hhmmString
        let base = "\(prescription.id)-\(dateStr)-\(timeStr)"
        var added = 0

        if await scheduleNotification(
            id: "\(base)-primary",
            title: prescription.name,
            body: "Time to take your dose.",
            at: adjustForQuietHours(date),
            prescriptionId: prescription.id.uuidString,
            scheduledDate: date.timeIntervalSince1970,
            timeSensitive: prescription.timeSensitive,
            center: center
        ) { added += 1 }

        // Follow-ups are optional. When enabled: one nudge, or a capped repeating
        // series gated on `repeatRemindersUntilDone` (a Rex Pro feature — guarded here
        // too so a lapsed entitlement can't keep scheduling the series).
        guard prescription.followUpEnabled else { return added }
        let repeats = prescription.repeatRemindersUntilDone && SharedDefaults.shared.proUnlocked
        let count = repeats ? maxRepeatFollowUps : 1
        let doseDay = Calendar.current.startOfDay(for: date)

        for n in 1 ... count {
            if added >= budget { break }
            let fireDate = adjustForQuietHours(
                date.addingTimeInterval(prescription.followUpInterval * Double(n))
            )
            // Keep a repeating series within the dose's own day — don't nag overnight or
            // across the quiet-hours gap into the next morning.
            if repeats, Calendar.current.startOfDay(for: fireDate) != doseDay { break }
            // A single follow-up keeps the legacy id; a series is suffixed -followup-N.
            let fid = count == 1 ? "\(base)-followup" : "\(base)-followup-\(n)"
            if await scheduleNotification(
                id: fid,
                title: prescription.name,
                body: "Don't forget your dose!",
                at: fireDate,
                prescriptionId: prescription.id.uuidString,
                scheduledDate: date.timeIntervalSince1970,
                timeSensitive: prescription.timeSensitive,
                center: center
            ) { added += 1 }
        }
        return added
    }

    // Returns true if a request was actually scheduled (i.e. the fire date is in the future).
    @discardableResult
    private static func scheduleNotification(
        id: String,
        title: String,
        body: String,
        at date: Date,
        prescriptionId: String,
        scheduledDate: TimeInterval,
        timeSensitive: Bool,
        center: UNUserNotificationCenter
    ) async -> Bool {
        guard date > Date() else { return false }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = "DOSE_REMINDER"
        content.sound = .default
        // Group all of a medication's reminders (primary + the whole follow-up series,
        // across occurrences) into one collapsible stack in Notification Center.
        content.threadIdentifier = prescriptionId
        // .timeSensitive breaks through Focus / Do Not Disturb (requires the Time
        // Sensitive Notifications capability). It does NOT override the silent switch —
        // that needs the Critical Alerts entitlement.
        content.interruptionLevel = timeSensitive ? .timeSensitive : .active
        content.userInfo = [
            "prescriptionId": prescriptionId,
            "scheduledDate": scheduledDate,
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
        return true
    }

    private static func adjustForQuietHours(_ date: Date) -> Date {
        let s = SharedDefaults.shared
        guard s.quietHoursEnabled else { return date }

        let start = s.quietHoursStartMinutes
        let end = s.quietHoursEndMinutes
        let minutes = date.minutesSinceMidnight

        let inQuiet: Bool
        if start > end {
            // Midnight-crossing (e.g. 22:00–07:00)
            inQuiet = minutes >= start || minutes < end
        } else {
            inQuiet = minutes >= start && minutes < end
        }

        guard inQuiet else { return date }

        // Shift to quietHoursEnd on same or next morning
        let cal = Calendar.current
        var targetDay = cal.startOfDay(for: date)
        let endHour = end / 60
        let endMinute = end % 60

        var shifted = cal.date(
            bySettingHour: endHour, minute: endMinute, second: 0, of: targetDay
        ) ?? date

        if shifted <= date {
            targetDay = cal.date(byAdding: .day, value: 1, to: targetDay) ?? targetDay
            shifted = cal.date(
                bySettingHour: endHour, minute: endMinute, second: 0, of: targetDay
            ) ?? date
        }
        return shifted
    }
}
