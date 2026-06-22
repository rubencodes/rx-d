import BackgroundTasks
import SwiftData
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationService.registerCategories()
        UNUserNotificationCenter.current().delegate = self
        registerBGTask()
        return true
    }

    // MARK: - Notification actions

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard
            let pidString = userInfo["prescriptionId"] as? String,
            let prescriptionId = UUID(uuidString: pidString),
            let scheduledInterval = userInfo["scheduledDate"] as? TimeInterval
        else {
            completionHandler()
            return
        }

        let scheduledDate = Date(timeIntervalSince1970: scheduledInterval)

        Task {
            await handleAction(
                response.actionIdentifier,
                prescriptionId: prescriptionId,
                scheduledDate: scheduledDate
            )
            completionHandler()
        }
    }

    private func handleAction(
        _ identifier: String,
        prescriptionId: UUID,
        scheduledDate: Date
    ) async {
        guard let container = try? ModelContainerFactory.makeSharedContainer() else { return }
        let context = ModelContext(container)

        switch identifier {
        case "DONE":
            // Upsert: an older occurrence may already have a log (e.g. a .missed one
            // created by the auto-miss pass). Marking DONE must update that record, not
            // insert a duplicate — otherwise the occurrence keeps showing as missed.
            let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
            if let existing = logs.first(where: {
                $0.prescriptionId == prescriptionId &&
                    Calendar.current.isDate($0.scheduledDate, equalTo: scheduledDate, toGranularity: .minute)
            }) {
                existing.status = .taken
                existing.completedAt = Date()
            } else {
                context.insert(DoseLog(
                    prescriptionId: prescriptionId,
                    scheduledDate: scheduledDate,
                    status: .taken,
                    completedAt: Date()
                ))
            }
            try? context.save()
            // Clear the whole reminder series for this occurrence (primary + follow-ups).
            NotificationService.cancelOccurrence(prescriptionId: prescriptionId, scheduledDate: scheduledDate)

        case "SNOOZE":
            let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
            if let existing = logs.first(where: {
                $0.prescriptionId == prescriptionId &&
                    Calendar.current.isDate($0.scheduledDate, equalTo: scheduledDate, toGranularity: .minute)
            }) {
                existing.status = .snoozed
                existing.snoozeCount += 1
            } else {
                let log = DoseLog(
                    prescriptionId: prescriptionId,
                    scheduledDate: scheduledDate,
                    status: .snoozed,
                    snoozeCount: 1
                )
                context.insert(log)
            }
            try? context.save()

        default:
            break
        }
    }

    // MARK: - Background Tasks

    private func registerBGTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "codes.ruben.rx-d.refresh",
            using: nil
        ) { task in
            self.handleBGRefresh(task: task as! BGAppRefreshTask)
        }
    }

    private func handleBGRefresh(task: BGAppRefreshTask) {
        scheduleNextBGRefresh()

        Task {
            guard let container = try? ModelContainerFactory.makeSharedContainer() else {
                task.setTaskCompleted(success: false)
                return
            }
            let context = ModelContext(container)
            do {
                try MissedDoseService.runAutoMissPass(context: context)
                let prescriptions = try context.fetch(FetchDescriptor<Prescription>())
                let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
                await NotificationService.rescheduleAll(prescriptions: prescriptions, logs: logs)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = { task.setTaskCompleted(success: false) }
    }

    private func scheduleNextBGRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "codes.ruben.rx-d.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
