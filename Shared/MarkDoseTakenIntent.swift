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

        // Cancel the follow-up notification for this occurrence
        let dateStr = date.isoDateString
        let timeStr = date.hhmmString
        let followUpId = "\(pid)-\(dateStr)-\(timeStr)-followup"
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [followUpId])

        return .result()
    }
}
