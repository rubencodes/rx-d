import SwiftUI

struct EnableHealthStep: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            PillBuddy(mood: .happy, topColor: Theme.accent, size: 92)
                .padding(.bottom, 12)
            Text("Connect Apple Health")
                .font(.title.bold())
                .foregroundStyle(Theme.ink)
            Text("Optionally link Apple Health to import medications you've already set up and see how your vitals track with your doses.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.inkFaded)
                .padding(.horizontal, 32)

            LabelCard {
                VStack(alignment: .leading, spacing: 12) {
                    benefit("pills.fill", "Import your medications")
                    benefit("chart.xyaxis.line", "Chart vitals against adherence")
                    benefit("lock.fill", "Read-only — rx'd never writes to Health")
                }
                .padding(16)
            }
            .padding(.horizontal, 32)

            Text("This shares your vitals. You'll pick which medications to share later, when you import them.")
                .font(.caption)
                .foregroundStyle(Theme.inkFaded)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()

            VStack(spacing: 12) {
                Button("Connect Apple Health") {
                    Task {
                        await HealthKitService.requestAuthorization()
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.accent)
                .disabled(!HealthKitService.isAvailable)

                Button("Maybe Later") { onComplete() }
                    .foregroundStyle(Theme.inkFaded)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer()
        }
    }
}
