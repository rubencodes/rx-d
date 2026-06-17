import SwiftUI
import SwiftData
import WidgetKit

struct TodayView: View {
    @Query(filter: #Predicate<Prescription> { !$0.isArchived })
    private var prescriptions: [Prescription]

    @Query private var allLogs: [DoseLog]
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedOccurrence: ScheduledOccurrence?
    @State private var confettiTrigger = 0

    var body: some View {
        NavigationStack {
            // Re-renders every minute so statuses (SOON/LATER/MISSED), the day's
            // dose list (midnight rollover), and the greeting stay fresh while the
            // screen is left open. `context.date` is the authoritative "now".
            TimelineView(.everyMinute) { context in
                listContent(now: context.date)
            }
            .background(Theme.background.ignoresSafeArea())
            .overlay(ConfettiBurst(trigger: confettiTrigger, reduceMotion: reduceMotion))
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedOccurrence) { occurrence in
                DoseDetailView(occurrence: occurrence)
            }
        }
    }

    @ViewBuilder
    private func listContent(now: Date) -> some View {
        let occurrences = occurrences(now: now)
        let taken = occurrences.filter { $0.effectiveStatus(asOf: now) == .taken }.count
        let total = occurrences.count
        let done = total > 0 && taken == total

        List {
            Section {
                header(now: now, taken: taken, total: total, done: done,
                       isEmpty: occurrences.isEmpty, next: nextPending(occurrences, now: now))
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if occurrences.isEmpty {
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(occurrences) { occurrence in
                        let status = occurrence.effectiveStatus(asOf: now)
                        DoseLabelCard(
                            occurrence: occurrence,
                            now: now,
                            reduceMotion: reduceMotion,
                            onToggle: { markTaken(occurrence) },
                            onOpen: { selectedOccurrence = occurrence }
                        )
                        .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                markTaken(occurrence)
                            } label: {
                                Label(status == .taken ? "Undo" : "Done",
                                      systemImage: status == .taken ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(status == .taken ? Theme.inkFaded : Theme.accent)
                        }
                    }
                } header: {
                    RuledHeader(title: "Today's Doses")
                        .textCase(nil)
                        .padding(.bottom, 4)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Data (relative to a supplied `now`)

    private func occurrences(now: Date) -> [ScheduledOccurrence] {
        let cal = Calendar.current
        let todayLogs = allLogs.filter { cal.isDate($0.scheduledDate, inSameDayAs: now) }
        return prescriptions
            .flatMap { prescription in
                ScheduleService.occurrences(for: prescription, on: now).map { date in
                    ScheduledOccurrence(
                        prescription: prescription,
                        scheduledDate: date,
                        doseLog: todayLogs.first {
                            $0.prescriptionId == prescription.id &&
                            cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute)
                        }
                    )
                }
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private func nextPending(_ occurrences: [ScheduledOccurrence], now: Date) -> ScheduledOccurrence? {
        occurrences.first { $0.effectiveStatus(asOf: now) == .pending }
    }

    // MARK: - Header

    private func header(now: Date, taken: Int, total: Int, done: Bool,
                        isEmpty: Bool, next: ScheduledOccurrence?) -> some View {
        LabelCard {
            HStack(spacing: 16) {
                PillBuddy(
                    mood: isEmpty ? .sleepy : (done ? .happy : .content),
                    topColor: done ? Theme.accent : Theme.oxblood,
                    size: 58
                )
                .frame(width: 92)
                .rotationEffect(.degrees(done && !reduceMotion ? -6 : 0))
                .animation(.spring(response: 0.5, dampingFraction: 0.4), value: done)

                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting(now: now))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    if total > 0 {
                        Text(done ? "All caught up — nice work!"
                                  : "\(taken) of \(total) doses taken")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkFaded)
                        if !done {
                            if let next {
                                // Auto-updating relative countdown (Apple's Text wrapper).
                                HStack(spacing: 4) {
                                    Text("Next dose")
                                    Text(next.scheduledDate, style: .relative)
                                }
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                            }
                            CapsuleProgress(value: Double(taken), total: Double(total))
                                .frame(height: 10)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    } else {
                        Text("Nothing on the schedule today.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkFaded)
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: done)
                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .overlay(alignment: .topTrailing) { streakBadge }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headerAccessibilityLabel(taken: taken, total: total, done: done, now: now))
        .padding(.top, 4)
    }

    @ViewBuilder private var streakBadge: some View {
        let streak = SharedDefaults.shared.streakCache
        if streak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                Text("\(streak)")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Theme.oxblood, in: Capsule())
            .padding(10)
            .accessibilityLabel("\(streak) day streak")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            PillBuddy(mood: .sleepy, topColor: Theme.pending, size: 92)
                .padding(.top, 24)
            Text("Nothing prescribed today")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text("Add a prescription in the Schedule tab and it'll show up here.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkFaded)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func greeting(now: Date) -> String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Hello"
        }
    }

    private func headerAccessibilityLabel(taken: Int, total: Int, done: Bool, now: Date) -> String {
        var label = greeting(now: now) + ". "
        if total == 0 {
            label += "Nothing scheduled today."
        } else if done {
            label += "All caught up, all \(total) doses taken."
        } else {
            label += "\(taken) of \(total) doses taken."
        }
        let streak = SharedDefaults.shared.streakCache
        if streak > 0 { label += " \(streak) day streak." }
        return label
    }

    private func markTaken(_ occurrence: ScheduledOccurrence) {
        let now = Date()
        let wasAllDone = isAllDone(now: now)
        let isTakenNow: Bool
        if let existing = occurrence.doseLog {
            existing.status = existing.status == .taken ? .pending : .taken
            existing.completedAt = existing.status == .taken ? Date() : nil
            isTakenNow = existing.status == .taken
        } else {
            let log = DoseLog(
                prescriptionId: occurrence.prescription.id,
                scheduledDate: occurrence.scheduledDate,
                status: .taken,
                completedAt: Date()
            )
            context.insert(log)
            isTakenNow = true
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        // Marking taken in-app must clear any pending reminders for this occurrence
        // (the DONE/widget paths already do this). On undo, the next reschedule pass
        // restores them since the dose is no longer taken.
        if isTakenNow {
            NotificationService.cancelOccurrence(
                prescriptionId: occurrence.prescription.id,
                scheduledDate: occurrence.scheduledDate
            )
        } else {
            Task { [prescriptions, allLogs] in
                await NotificationService.rescheduleAll(prescriptions: prescriptions, logs: allLogs)
            }
        }

        Haptics.tap()
        if !wasAllDone && isAllDone(now: now) {
            Haptics.success()
            confettiTrigger += 1
        }
    }

    private func isAllDone(now: Date) -> Bool {
        let occ = occurrences(now: now)
        return !occ.isEmpty && occ.allSatisfy { $0.effectiveStatus(asOf: now) == .taken }
    }
}
