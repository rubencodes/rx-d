import SwiftData
import SwiftUI

struct OnboardingFlow: View {
    let onComplete: () -> Void

    @State private var step = initialStep()
    @Environment(\.modelContext) private var context
    // Returning users (restored from the surviving store or synced via iCloud) already
    // have prescriptions, so we skip the "add your first medication" step for them.
    @Query private var prescriptions: [Prescription]

    private static func initialStep() -> Int {
        #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--onboarding-step"), i + 1 < args.count,
               let n = Int(args[i + 1])
            {
                return n
            }
        #endif
        return 0
    }

    var body: some View {
        switch step {
        case 0:
            // Skip the add-medication step if the user already has prescriptions
            // (e.g. data restored on reinstall or synced from iCloud).
            WelcomeStep { step = prescriptions.isEmpty ? 1 : 2 }
        case 1:
            // Apple Health is connected later — from a tip on the Add screen (medications)
            // and the Health tab (vitals) — so onboarding stays short.
            AddFirstPrescriptionStep { step = 2 }
        default:
            EnableNotificationsStep {
                SharedDefaults.shared.hasCompletedOnboarding = true
                onComplete()
            }
        }
    }
}
