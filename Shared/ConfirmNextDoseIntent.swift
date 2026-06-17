import AppIntents

// Used by the Control Center "Next Dose" control. Control buttons run headlessly
// (no confirmation UI), so instead of marking directly this opens the app and stashes
// the dose; the app then presents a "Mark as taken?" confirmation. Avoids accidental
// taps in Control Center silently changing data.
struct ConfirmNextDoseIntent: AppIntent {
    static var title: LocalizedStringResource = "Take Next Dose"
    static var description = IntentDescription("Opens rx'd to confirm taking your next dose.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Prescription ID") var prescriptionId: String
    @Parameter(title: "Scheduled Date") var scheduledDate: Double
    @Parameter(title: "Dose Name") var doseName: String

    init() {}

    init(prescriptionId: String, scheduledDate: Double, doseName: String) {
        self.prescriptionId = prescriptionId
        self.scheduledDate = scheduledDate
        self.doseName = doseName
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard !prescriptionId.isEmpty else { return .result() }
        // name may contain "|"; it's parsed as the remainder, so this is safe.
        SharedDefaults.shared.pendingDoseConfirmation = "\(prescriptionId)|\(scheduledDate)|\(doseName)"
        return .result()
    }
}
