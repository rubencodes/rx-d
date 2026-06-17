import WidgetKit
import SwiftUI
import AppIntents

// Widget content view. Lives in Shared so it can also be rendered in an in-app
// preview gallery; the Widget configuration itself stays in the widget target.
struct PrescriptionWidgetView: View {
    @Environment(\.widgetFamily) private var envFamily
    var familyOverride: WidgetFamily? = nil   // DEBUG gallery only; widget uses the env value
    let entry: DoseEntry

    private var family: WidgetFamily { familyOverride ?? envFamily }

    private var allDone: Bool {
        !entry.items.isEmpty && entry.items.allSatisfy { $0.status == .taken }
    }

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemLarge: largeView
        default:           mediumView
        }
    }

    // MARK: - Small: one dose, styled as a prescription label

    private var smallView: some View {
        Group {
            if let item = nextItem {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        RxMonogram(size: 24, color: Color(hex: item.colorHex))
                        Spacer()
                        StatusStamp(status: item.status, scheduledDate: item.scheduledDate, now: entry.date)
                    }
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text(item.scheduledDate, style: .time)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkFaded)
                    Spacer(minLength: 4)
                    checkButton(for: item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                emptyOrDone
            }
        }
    }

    // MARK: - Medium: today's list (or celebration)

    private var mediumView: some View {
        Group {
            if entry.items.isEmpty {
                emptyOrDone
            } else if allDone {
                allCaughtUp
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    headerRow
                    ForEach(Array(entry.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(Theme.ink.opacity(0.12)) }
                        doseRow(item)
                    }
                    if entry.items.count > 3 {
                        Text("+\(entry.items.count - 3) more")
                            .font(.caption2).foregroundStyle(Theme.inkFaded)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Today")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("· \(takenCount)/\(entry.items.count)")
                .font(.subheadline)
                .foregroundStyle(Theme.inkFaded)
            Spacer()
            if entry.streak > 0 {
                Label("\(entry.streak)", systemImage: "flame.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.oxblood)
            }
        }
    }

    private func doseRow(_ item: DoseItem) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: item.colorHex)).frame(width: 8, height: 8)
            Text(item.name)
                .font(.subheadline)
                .foregroundStyle(item.status == .taken ? Theme.inkFaded : Theme.ink)
                .strikethrough(item.status == .taken, color: Theme.inkFaded)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(item.scheduledDate, style: .time)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.inkFaded)
            miniCheck(for: item)
        }
    }

    // MARK: - Large: fuller today's list + progress

    private var largeView: some View {
        Group {
            if entry.items.isEmpty {
                emptyOrDone
            } else if allDone {
                allCaughtUp
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Today").font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        if entry.streak > 0 {
                            Label("\(entry.streak)", systemImage: "flame.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.oxblood)
                        }
                    }
                    progressBar
                        .frame(height: 9)
                    RuledHeader(title: "\(takenCount) of \(entry.items.count) taken")
                    VStack(spacing: 9) {
                        ForEach(Array(entry.items.prefix(6).enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Divider().overlay(Theme.ink.opacity(0.1)) }
                            largeRow(item)
                        }
                    }
                    if entry.items.count > 6 {
                        Text("+\(entry.items.count - 6) more")
                            .font(.caption2).foregroundStyle(Theme.inkFaded)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func largeRow(_ item: DoseItem) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color(hex: item.colorHex)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(item.status == .taken ? Theme.inkFaded : Theme.ink)
                    .strikethrough(item.status == .taken, color: Theme.inkFaded)
                    .lineLimit(1)
                Text(item.scheduledDate, style: .time)
                    .font(.caption2).foregroundStyle(Theme.inkFaded)
            }
            Spacer(minLength: 6)
            StatusStamp(status: item.status, scheduledDate: item.scheduledDate, now: entry.date)
            miniCheck(for: item)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let ratio = entry.items.isEmpty ? 0 : Double(takenCount) / Double(entry.items.count)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceAlt)
                Capsule().fill(Theme.taken).frame(width: max(0, min(1, ratio)) * geo.size.width)
            }
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Shared states

    private var emptyOrDone: some View {
        VStack(spacing: 10) {
            PillBuddy(mood: .sleepy, topColor: Theme.pending, size: family == .systemSmall ? 44 : 52)
            Text("No doses today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkFaded)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var allCaughtUp: some View {
        HStack(spacing: 14) {
            PillBuddy(mood: .happy, topColor: Theme.accent, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("All caught up")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("All \(entry.items.count) doses taken today")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaded)
                if entry.streak > 0 {
                    Label("\(entry.streak) day streak", systemImage: "flame.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.oxblood)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var takenCount: Int { entry.items.filter { $0.status == .taken }.count }

    private var nextItem: DoseItem? {
        entry.items.first { $0.status == .pending } ?? entry.items.first
    }

    private func checkButton(for item: DoseItem) -> some View {
        Button(intent: MarkDoseTakenIntent(
            prescriptionId: item.prescriptionId.uuidString,
            scheduledDate: item.scheduledDate.timeIntervalSince1970
        )) {
            HStack(spacing: 5) {
                Image(systemName: item.status == .taken ? "checkmark" : "circle")
                Text(item.status == .taken ? "Taken" : "Mark Done")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(item.status == .taken ? Theme.taken : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                item.status == .taken ? Theme.taken.opacity(0.15) : Theme.accent,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(item.status == .taken)
        .accessibilityLabel(item.status == .taken ? "\(item.name) taken" : "Mark \(item.name) taken")
    }

    private func miniCheck(for item: DoseItem) -> some View {
        Button(intent: MarkDoseTakenIntent(
            prescriptionId: item.prescriptionId.uuidString,
            scheduledDate: item.scheduledDate.timeIntervalSince1970
        )) {
            Image(systemName: item.status == .taken ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(item.status == .taken ? Theme.taken : Theme.inkFaded)
        }
        .buttonStyle(.plain)
        .disabled(item.status == .taken)
        .accessibilityLabel(item.status == .taken ? "\(item.name) taken" : "Mark \(item.name) taken")
    }
}
