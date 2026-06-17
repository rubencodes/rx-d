import AppIntents
import WidgetKit

// Widget configuration: optionally pick one prescription to track.
// Leaving it unset (the default) shows all of today's doses.
struct PrescriptionSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Select Prescription" }
    static var description: IntentDescription { "Track all doses, or pick one prescription." }

    @Parameter(title: "Prescription (optional)")
    var prescription: PrescriptionEntity?
}
