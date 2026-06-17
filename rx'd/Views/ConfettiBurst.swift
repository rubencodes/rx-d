import SwiftUI

// A one-shot confetti burst of tiny pills & dots in apothecary colors.
// Re-fires whenever `trigger` changes. Skipped entirely under Reduce Motion.
struct ConfettiBurst: View {
    var trigger: Int
    var reduceMotion: Bool

    private struct Piece: Identifiable {
        let id = UUID()
        let angle: Double      // radians
        let speed: CGFloat
        let color: Color
        let isPill: Bool
        let spin: Double
    }

    private static let palette: [Color] = [
        Theme.accent, Theme.oxblood, Theme.gold, Theme.taken, Theme.ink
    ]

    private let pieces: [Piece] = (0..<30).map { i in
        Piece(
            angle: .pi * (0.15 + 0.7 * Double(i) / 29.0) + .pi,   // fan upward
            speed: CGFloat.random(in: 160...340),
            color: palette[i % palette.count],
            isPill: i % 2 == 0,
            spin: Double.random(in: -540...540)
        )
    }

    @State private var t: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let origin = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.32)
            ZStack {
                ForEach(pieces) { p in
                    piece(p)
                        .position(
                            x: origin.x + cos(p.angle) * p.speed * t,
                            y: origin.y + sin(p.angle) * p.speed * t + 420 * t * t  // gravity
                        )
                        .rotationEffect(.degrees(p.spin * Double(t)))
                        .opacity(t == 0 ? 0 : Double(1 - t))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion, trigger > 0 else { return }
            t = 0
            withAnimation(.easeOut(duration: 1.2)) { t = 1 }
        }
    }

    @ViewBuilder private func piece(_ p: Piece) -> some View {
        if p.isPill {
            Capsule().fill(p.color).frame(width: 12, height: 6)
        } else {
            Circle().fill(p.color).frame(width: 7, height: 7)
        }
    }
}
