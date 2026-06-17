import SwiftUI

struct CapsuleProgress: View {
    let value: Double
    let total: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The displayed proportion. Animating on this (rather than `value`) keeps the
    // fill smooth whether the taken count or the total changes.
    private var fraction: Double {
        max(0, min(1, total == 0 ? 0 : value / total))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceAlt)
                Capsule()
                    .fill(Theme.taken)
                    .frame(width: fraction * geo.size.width)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: fraction)
            }
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1))
        }
    }
}
