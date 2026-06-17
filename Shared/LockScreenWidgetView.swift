import SwiftUI
import WidgetKit

// Lock-screen accessory content. Accessory families render monochrome, so we lean
// on SF Symbols + text (and the ℞ glyph) rather than color.
struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var envFamily
    var familyOverride: WidgetFamily? = nil // DEBUG gallery only
    let entry: DoseEntry

    private var family: WidgetFamily { familyOverride ?? envFamily }

    var body: some View {
        switch family {
        case .accessoryCircular: circularView
        case .accessoryInline: inlineView
        default: rectangularView
        }
    }

    // Minimal read-only next-dose line (sits by the lock-screen clock).
    private var inlineView: some View {
        let next = entry.items.first { $0.status == .pending }
        return Label(
            next.map { "\($0.name), \($0.scheduledDate.formatted(date: .omitted, time: .shortened))" }
                ?? "All doses taken",
            systemImage: next == nil ? "checkmark.circle" : "pills.fill"
        )
    }

    private var takenCount: Int { entry.items.filter { $0.status == .taken }.count }
    private var total: Int { entry.items.count }

    private var circularView: some View {
        Gauge(value: Double(takenCount), in: 0 ... Double(max(total, 1))) {
            Image(systemName: "pill.fill")
        } currentValueLabel: {
            Text("\(takenCount)/\(total)")
                .font(.caption2)
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityLabel("Doses")
        .accessibilityValue("\(takenCount) of \(total) taken today")
    }

    private var rectangularView: some View {
        let next = entry.items.first { $0.status == .pending }
        return VStack(alignment: .leading, spacing: 2) {
            if let next {
                HStack(spacing: 4) {
                    Text(Theme.rx).font(.caption.weight(.bold))
                    Text(next.name).font(.headline).lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(next.scheduledDate, style: .time)
                    Text("· \(next.scheduledDate.timeIntervalSince(entry.date) <= 3600 ? "soon" : "later")")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            } else if total > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("All caught up").font(.headline)
                }
                Text("\(takenCount)/\(total) doses today")
                    .font(.caption)
            } else {
                HStack(spacing: 4) {
                    Text(Theme.rx).font(.caption.weight(.bold))
                    Text("No doses today").font(.headline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
