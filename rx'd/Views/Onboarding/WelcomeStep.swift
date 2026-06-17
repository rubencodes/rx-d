import SwiftUI

struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            PillBuddy(mood: .happy, topColor: Theme.accent, size: 120)
            VStack(spacing: 10) {
                RxMonogram(size: 30)
                Text("rx'd")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
            }
            Text("Keep your prescriptions filled and never miss a dose.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.inkFaded)
                .padding(.horizontal, 32)
            Spacer()
            Button("Get Started") { onNext() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}
