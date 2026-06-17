import SwiftUI

// A cream "prescription label" card: paper fill with a double-ruled border.
struct LabelCard<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .strokeBorder(Theme.ink.opacity(0.55), lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius - 3)
                    .strokeBorder(Theme.ink.opacity(0.22), lineWidth: 1)
                    .padding(3)
            )
            .shadow(color: Theme.cardShadow, radius: 6, y: 3)
    }
}
