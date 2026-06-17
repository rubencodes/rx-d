import Foundation
import UserNotifications

enum NotificationService {
    static let maxPending = 60 // keep 4 slots free for snooze notifications
    static let daysAhead = 7

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
                    await schedule(prescription: prescription, at: date, center: center)
                    scheduled += 2 // primary + follow-up
                }
            }
        }
    }

    // Cancel both the primary and follow-up reminders for a single occurrence. Used
    // when a dose is marked taken from inside the app (tap/swipe in Today, or the
    // Control Center confirmation), which otherwise wouldn't clear the pending
    // follow-up reminder until the next full reschedule.
    static func cancelOccurrence(prescriptionId: UUID, scheduledDate: Date) {
        let dateStr = scheduledDate.isoDateString
        let timeStr = scheduledDate.hhmmString
        let ids = [
            "\(prescriptionId)-\(dateStr)-\(timeStr)-primary",
            "\(prescriptionId)-\(dateStr)-\(timeStr)-followup",
        ]
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
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

    static func cancelFollowUp(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Private

    private static func schedule(
        prescription: Prescription,
        at date: Date,
        center: UNUserNotificationCenter
    ) async {
        let dateStr = date.isoDateString
        let timeStr = date.hhmmString
        let primaryId = "\(prescription.id)-\(dateStr)-\(timeStr)-primary"
        let followUpId = "\(prescription.id)-\(dateStr)-\(timeStr)-followup"

        let primaryDate = adjustForQuietHours(date)
        let followUpDate = adjustForQuietHours(
            date.addingTimeInterval(prescription.followUpInterval)
        )

        await scheduleNotification(
            id: primaryId,
            title: prescription.name,
            body: "Time to take your dose.",
            at: primaryDate,
            prescriptionId: prescription.id.uuidString,
            scheduledDate: date.timeIntervalSince1970,
            followUpId: followUpId,
            center: center
        )

        await scheduleNotification(
            id: followUpId,
            title: prescription.name,
            body: "Don't forget your dose!",
            at: followUpDate,
            prescriptionId: prescription.id.uuidString,
            scheduledDate: date.timeIntervalSince1970,
            followUpId: nil,
            center: center
        )
    }

    private static func scheduleNotification(
        id: String,
        title: String,
        body: String,
        at date: Date,
        prescriptionId: String,
        scheduledDate: TimeInterval,
        followUpId: String?,
        center: UNUserNotificationCenter
    ) async {
        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = "DOSE_REMINDER"
        content.sound = .default
        var info: [String: Any] = [
            "prescriptionId": prescriptionId,
            "scheduledDate": scheduledDate,
        ]
        if let fid = followUpId { info["followUpId"] = fid }
        content.userInfo = info

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
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
