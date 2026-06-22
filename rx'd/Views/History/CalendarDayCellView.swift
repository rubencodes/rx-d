import SwiftUI

struct CalendarDayCellView: View {
    let day: Date
    let adherence: DayAdherence
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(Theme.accent)
            } else if adherence.total > 0 {
                Circle().fill(adherence.color.opacity(0.28))
                Circle().strokeBorder(adherence.color.opacity(0.7), lineWidth: 1.5)
            }
            if isToday && !isSelected {
                Circle().strokeBorder(Theme.oxblood, lineWidth: 1.5)
            } else {
                Circle().fill(.clear)
            }

            Text(day.formatted(.dateTime.day()))
                .font(.callout.weight(isToday ? .bold : .regular))
                .foregroundStyle(isSelected ? Color.white : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(minHeight: 38)
        .animation(.spring, value: isSelected)
        .animation(.spring, value: adherence.total)
        .animation(.spring, value: isToday)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(accessibilityTraits)
    }

    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = .isButton
        if isSelected { traits.formUnion(.isSelected) }
        return traits
    }

    private var accessibilityLabel: String {
        let dateStr = day.formatted(date: .complete, time: .omitted)
        let todaySuffix = isToday ? ", today" : ""
        if adherence.total == 0 {
            return "\(dateStr)\(todaySuffix), no doses scheduled"
        }
        return "\(dateStr)\(todaySuffix), \(adherence.taken) of \(adherence.total) doses taken"
    }
}
