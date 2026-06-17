import AppIntents
import SwiftUI
import WidgetKit

// Control Center / Lock Screen control showing the next pending dose.
// Tapping marks it taken (no-op when there's nothing due).
struct NextDoseControl: ControlWidget {
    static let kind = "codes.ruben.rx-d.NextDose"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: NextDoseControlProvider()) { value in
            ControlWidgetButton(action: ConfirmNextDoseIntent(
                prescriptionId: value.prescriptionId,
                scheduledDate: value.scheduledDate,
                doseName: value.title
            )) {
                Label(value.title, systemImage: value.hasDose ? "pills.fill" : "checkmark.circle.fill")
                if !value.subtitle.isEmpty {
                    Text(value.subtitle)
                }
            }
            .disabled(!value.hasDose)
        }
        .displayName("Next Dose")
        .description("Shows your next dose; tap to confirm taking it in the app.")
    }
}
