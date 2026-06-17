import SwiftUI

// A tilted rubber-ink stamp for dose status.
// For a pending (future) dose, pass `scheduledDate` so it reads SOON / LATER
// instead of a misleading "DUE".
struct StatusStamp: View {
    let status: DoseStatus
    var scheduledDate: Date? = nil
    var now: Date = Date()

    private var label: String {
        if status == .pending, let date = scheduledDate {
            return date.timeIntervalSince(now) <= 3600 ? "SOON" : "LATER"
        }
        return status.stampLabel
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.heavy))
            .tracking(1.5)
            .foregroundStyle(status.themeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(status.themeColor, lineWidth: 1.5)
            )
            .rotationEffect(.degrees(-6))
            .opacity(0.9)
    }
}
