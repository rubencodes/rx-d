import SwiftUI

// Text-only attribution chip for data sourced from Apple Health.
// Per Apple's guidelines we use the name in text only — no Apple logo or Health icon.
struct AppleHealthBadge: View {
    var body: some View {
        Text("Apple Health")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.inkFaded)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.surfaceAlt, in: Capsule())
            .accessibilityLabel("Logged in Apple Health")
    }
}
