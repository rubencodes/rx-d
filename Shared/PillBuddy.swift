import SwiftUI

// A vintage amber apothecary bottle mascot with a ruled label and a little face.
// Shape-drawn, no assets. Kept the name `PillBuddy` for call-site compatibility.
struct PillBuddy: View {
    enum Mood { case happy, content, sleepy }

    var mood: Mood = .content
    var topColor: Color = Theme.accent   // tints the cap + label rule
    var size: CGFloat = 96

    private var w: CGFloat { size }
    private var h: CGFloat { size * 1.5 }

    var body: some View {
        ZStack(alignment: .top) {
            // Bottle body (amber glass)
            RoundedRectangle(cornerRadius: size * 0.16)
                .fill(LinearGradient(
                    colors: [Color(light: 0xCB8136, dark: 0xB06B23),
                             Color(light: 0xA8611E, dark: 0x8A4F18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: w * 0.92, height: h * 0.78)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.16)
                        .strokeBorder(Color.black.opacity(0.18), lineWidth: 1))
                .offset(y: h * 0.22)

            // Highlight glint on the glass
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: size * 0.10, height: h * 0.4)
                .offset(x: -w * 0.26, y: h * 0.32)

            // Cap
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(LinearGradient(colors: [topColor, topColor.opacity(0.78)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: w * 0.74, height: h * 0.2)
                .overlay(RoundedRectangle(cornerRadius: size * 0.05)
                    .strokeBorder(Color.black.opacity(0.18), lineWidth: 1))

            // Label with face
            label
                .frame(width: w * 0.74, height: h * 0.4)
                .offset(y: h * 0.36)
        }
        .frame(width: w, height: h)
        .shadow(color: Theme.cardShadow, radius: 7, y: 4)
    }

    private var label: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(light: 0xF6EFDD, dark: 0xEADFC6))
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(topColor.opacity(0.65), lineWidth: 1.2)
                .padding(2)
            VStack(spacing: size * 0.05) {
                face
                Rectangle().fill(topColor.opacity(0.5)).frame(height: 1).padding(.horizontal, size * 0.1)
            }
            .padding(.vertical, size * 0.07)
        }
    }

    @ViewBuilder private var face: some View {
        VStack(spacing: size * 0.04) {
            HStack(spacing: size * 0.14) { eye; eye }
            mouth
        }
        .foregroundStyle(Color(light: 0x4A3826, dark: 0x4A3826))
    }

    @ViewBuilder private var eye: some View {
        switch mood {
        case .happy:
            Arc(up: true)
                .stroke(Color(light: 0x4A3826, dark: 0x4A3826),
                        style: .init(lineWidth: size * 0.04, lineCap: .round))
                .frame(width: size * 0.13, height: size * 0.08)
        case .sleepy:
            Capsule().frame(width: size * 0.12, height: size * 0.035)
        case .content:
            Circle().frame(width: size * 0.08, height: size * 0.08)
        }
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .happy:
            Arc(up: false)
                .stroke(Color(light: 0x4A3826, dark: 0x4A3826),
                        style: .init(lineWidth: size * 0.045, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.11)
        case .content:
            Arc(up: false)
                .stroke(Color(light: 0x4A3826, dark: 0x4A3826),
                        style: .init(lineWidth: size * 0.04, lineCap: .round))
                .frame(width: size * 0.13, height: size * 0.06)
        case .sleepy:
            Circle().frame(width: size * 0.045, height: size * 0.045)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        PillBuddy(mood: .happy)
        PillBuddy(mood: .content)
        PillBuddy(mood: .sleepy, topColor: Theme.pending)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
}
