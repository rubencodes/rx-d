import SwiftUI
import UserNotifications

struct EnableNotificationsStep: View {
    let onComplete: () -> Void

    private let notificationCenter: UNUserNotificationCenter = .current()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            PillBuddy(mood: .content, topColor: Theme.oxblood, size: 96)
            Text("Stay on Track")
                .font(.title.bold())
                .foregroundStyle(Theme.ink)
            Text("Enable reminders so rx'd can notify you when it's time to take your doses.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.inkFaded)
                .padding(.horizontal, 32)

            // Mockup notification preview, styled as a prescription label
            LabelCard {
                HStack {
                    RxMonogram(size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morning Vitamins").font(.headline).foregroundStyle(Theme.ink)
                        Text("Time to take your dose.").font(.caption).foregroundStyle(Theme.inkFaded)
                    }
                    Spacer()
                }
                .padding(16)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button("Turn On Reminders") {
                    Task {
                        _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.accent)

                Button("Not Now") { onComplete() }
                    .foregroundStyle(Theme.inkFaded)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}
