import SwiftUI

struct CalendarView: View {
    @Binding var displayedMonth: Date
    let allLogs: [DoseLog]
    let allPrescriptions: [Prescription]

    @State private var selectedDay: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let cal = Calendar.current
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        // Re-renders each minute so today's adherence color, the "today" highlight
        // (incl. midnight rollover), and the day-detail statuses stay current.
        TimelineView(.everyMinute) { context in
            calendarBody(now: context.date)
        }
    }

    @ViewBuilder
    private func calendarBody(now: Date) -> some View {
        VStack(spacing: 0) {
            monthHeader
            dayOfWeekRow
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(gridDays, id: \.self) { day in
                    if let day {
                        CalendarDayCellView(
                            day: day,
                            adherence: adherence(for: day, now: now),
                            isToday: cal.isDate(day, inSameDayAs: now),
                            isSelected: selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false
                        )
                        .onTapGesture { selectedDay = day }
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
            .padding(.horizontal, 8)

            if let day = selectedDay {
                Divider().padding(.top, 8)
                DayDetailView(
                    day: day,
                    allLogs: allLogs,
                    allPrescriptions: allPrescriptions,
                    now: now
                )
            } else {
                Spacer()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 {
                        advanceMonth(by: 1)
                    } else if value.translation.width > 50 {
                        advanceMonth(by: -1)
                    }
                }
        )
    }

    private var monthHeader: some View {
        HStack {
            Button { advanceMonth(by: -1) } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
            }
            Spacer()
            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button { advanceMonth(by: 1) } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
            }
        }
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var dayOfWeekRow: some View {
        HStack {
            ForEach(dayLabels, id: \.self) { label in
                Text(label.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.inkFaded)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private var gridDays: [Date?] {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))!
        let firstWeekday = cal.component(.weekday, from: start) - 1 // 0-indexed
        let daysInMonth = cal.range(of: .day, in: .month, for: start)!.count

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in 0 ..< daysInMonth {
            days.append(cal.date(byAdding: .day, value: day, to: start))
        }
        return days
    }

    private func adherence(for day: Date, now: Date) -> DayAdherence {
        DayAdherence.compute(prescriptions: allPrescriptions, logs: allLogs, day: day, now: now)
    }

    private func advanceMonth(by months: Int) {
        if let next = cal.date(byAdding: .month, value: months, to: displayedMonth) {
            displayedMonth = next
        }
    }
}
