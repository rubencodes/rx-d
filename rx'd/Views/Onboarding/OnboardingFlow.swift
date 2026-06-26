import SwiftData
import SwiftUI

struct OnboardingFlow: View {
    let onComplete: () -> Void

    @State private var step = initialStep()
    @Environment(\.modelContext) private var context

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
            WelcomeStep {
                // Connect Health before adding a medication so it can be imported.
                // The Health step is iOS 26+ and only when HealthKit is available;
                // otherwise skip straight to adding a medication.
                if #available(iOS 26, *), HealthKitService.isAvailable {
                    step = 1
                } else {
                    step = 2
                }
            }
        case 1:
            if #available(iOS 26, *), HealthKitService.isAvailable {
                EnableHealthStep { step = 2 }
            }
        case 2:
            AddFirstPrescriptionStep { step = 3 }
        default:
            EnableNotificationsStep {
                SharedDefaults.shared.hasCompletedOnboarding = true
                onComplete()
            }
        }
    }
}
