import SwiftUI

struct CapsuleProgress: View {
    let value: Double
    let total: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceAlt)
                Capsule()
                    .fill(Theme.taken)
                    .frame(width: max(0, min(1, total == 0 ? 0 : value / total)) * geo.size.width)
            }
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1))
        }
    }
}
