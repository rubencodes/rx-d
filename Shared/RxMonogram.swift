import SwiftUI

// The ℞ monogram in a ruled box.
struct RxMonogram: View {
    var size: CGFloat = 30
    var color: Color = Theme.oxblood
    var body: some View {
        Text(Theme.rx)
            .font(.system(size: size * 0.62, weight: .bold, design: .serif))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(color, lineWidth: 1.5))
    }
}
