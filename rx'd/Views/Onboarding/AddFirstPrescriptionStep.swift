import SwiftUI

struct AddFirstPrescriptionStep: View {
    let onNext: () -> Void

    var body: some View {
        // AddEditPrescriptionView provides its own NavigationStack. Saving (or skipping)
        // advances the flow; the system notification prompt is deferred to the next step.
        AddEditPrescriptionView(
            onSaved: onNext,
            onCancel: onNext,
            requestsNotificationPermission: false,
            footerNote: "You can add more prescriptions anytime from the Schedule tab."
        )
    }
}
