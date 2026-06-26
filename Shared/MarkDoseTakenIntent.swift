import AppIntents
import SwiftData
import UserNotifications

// Interactive widget button intent — writes a .taken DoseLog to the shared store.
// Defined in Shared/ so both the app and widget extension can reference it.
struct MarkDoseTakenIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Dose Taken"

    @Parameter(title: "Prescription ID") var prescriptionId: String
    @Parameter(title: "Scheduled Date") var scheduledDate: Double

    init() {}

    init(prescriptionId: String, scheduledDate: Double) {
        self.prescriptionId = prescriptionId
        self.scheduledDate = scheduledDate
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let pid = UUID(uuidString: prescriptionId) else { return .result() }
        let date = Date(timeIntervalSince1970: scheduledDate)

        let container = try ModelContainerFactory.makeSharedContainer()
        let context = ModelContext(container)

        // Upsert: find an existing log for this prescription + scheduled minute
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
        if let existing = logs.first(where: {
            $0.prescriptionId == pid &&
                Calendar.current.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute)
        }) {
            existing.status = .taken
            existing.completedAt = Date()
        } else {
            let log = DoseLog(
                prescriptionId: pid,
                scheduledDate: date,
                status: .taken,
                completedAt: Date()
            )
            context.insert(log)
        }
        try? context.save()

        // Clear reminders for this dose. Done inline rather than via NotificationService
        // because this intent also runs in the widget extension, which doesn't compile
        // that service. Pending: this occurrence's series. Delivered: any already-shown
        // banners for the whole medication (Notification Center / Lock Screen).
        let center = UNUserNotificationCenter.current()
        let occurrencePrefix = "\(pid)-\(date.isoDateString)-\(date.hhmmString)-"
        let medicationPrefix = "\(pid)-"

        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(occurrencePrefix) }
        )

        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(
            withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix(medicationPrefix) }
        )

        return .result()
    }
}
