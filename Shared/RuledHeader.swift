import SwiftUI

// A centered small-caps title flanked by horizontal rules (apothecary label header).
struct RuledHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 10) {
            rule
            Text(title.uppercased())
                .font(.footnote.weight(.bold))
                .tracking(2)
                .foregroundStyle(Theme.inkFaded)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            rule
        }
    }
    private var rule: some View {
        Rectangle().fill(Theme.inkFaded.opacity(0.4)).frame(height: 1)
    }
}
