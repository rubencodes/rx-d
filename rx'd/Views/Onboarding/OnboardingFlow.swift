import SwiftUI

struct OnboardingFlow: View {
    let onComplete: () -> Void

    @State private var step = initialStep()
    @Environment(\.modelContext) private var context

    private static func initialStep() -> Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--onboarding-step"), i + 1 < args.count,
           let n = Int(args[i + 1]) {
            return n
        }
        #endif
        return 0
    }

    var body: some View {
        switch step {
        case 0:
            WelcomeStep { step = 1 }
        case 1:
            AddFirstPrescriptionStep { step = 2 }
        case 2:
            EnableNotificationsStep(onComplete: { step = 3 })
        default:
            EnableHealthStep(onComplete: {
                SharedDefaults.shared.hasCompletedOnboarding = true
                onComplete()
            })
        }
    }
}
