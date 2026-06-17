import SwiftUI
import WidgetKit

struct CalendarWidgetView: View {
    let entry: CalendarEntry
    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var leadingBlanks: Int {
        guard let first = entry.days.first else { return 0 }
        return cal.component(.weekday, from: first.date) - 1
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(entry.monthStart, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                HStack(spacing: 5) {
                    legendDot(Theme.taken)
                    legendDot(Theme.snoozed)
                    legendDot(Theme.missed)
                }
            }

            HStack(spacing: 3) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.inkFaded)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(0 ..< leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 26) }
                ForEach(entry.days) { day in cell(day) }
            }
            Spacer(minLength: 0)
        }
    }

    private func cell(_ day: CalendarDay) -> some View {
        let isToday = cal.isDate(day.date, inSameDayAs: entry.date)
        return ZStack {
            if day.adherence.total > 0 {
                Circle().fill(day.adherence.color.opacity(0.28))
                Circle().strokeBorder(day.adherence.color.opacity(0.7), lineWidth: 1.2)
            }
            if isToday {
                Circle().strokeBorder(Theme.oxblood, lineWidth: 1.5)
            }
            Text("\(cal.component(.day, from: day.date))")
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(Theme.ink)
        }
        .frame(height: 26)
    }

    private func legendDot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 7, height: 7)
    }
}
