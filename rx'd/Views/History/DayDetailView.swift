import SwiftData
import SwiftUI
import WidgetKit

struct DayDetailView: View {
    let day: Date
    let allLogs: [DoseLog]
    let allPrescriptions: [Prescription]
    var now: Date = .init()

    @Environment(\.modelContext) private var context
    @State private var confirmRetroactive: ScheduledOccurrence?

    private let cal = Calendar.current

    private var occurrences: [ScheduledOccurrence] {
        let dayLogs = allLogs.filter { cal.isDate($0.scheduledDate, inSameDayAs: day) }
        return allPrescriptions
            .flatMap { prescription in
                ScheduleService.occurrences(for: prescription, on: day).map { date in
                    ScheduledOccurrence(
                        prescription: prescription,
                        scheduledDate: date,
                        doseLog: dayLogs.first {
                            $0.prescriptionId == prescription.id &&
                                cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute)
                        }
                    )
                }
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var isPast: Bool { day < cal.startOfDay(for: now) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(day, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                if occurrences.isEmpty {
                    Text("No doses scheduled")
                        .foregroundStyle(.secondary)
                        .padding(16)
                } else {
                    ForEach(occurrences) { occ in
                        Divider()
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: occ.prescription.color)
                                    .opacity(occ.prescription.isArchived ? 0.4 : 1))
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(occ.prescription.name)
                                    .font(.body)
                                    .italic(occ.prescription.isArchived)
                                if let completedAt = occ.doseLog?.completedAt {
                                    Text("Taken at \(completedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(occ.scheduledDate, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let note = occ.doseLog?.noteText {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let filename = occ.doseLog?.photoFilename,
                                   let image = PhotoStore.load(filename)
                                {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                if occ.doseLog?.isFromHealth == true {
                                    AppleHealthBadge()
                                }
                            }

                            Spacer()

                            statusView(for: occ)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isPast && occ.effectiveStatus(asOf: now) == .missed {
                                confirmRetroactive = occ
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(rowAccessibilityLabel(occ))
                        .accessibilityAction(named: "Mark taken late") {
                            if isPast && occ.effectiveStatus(asOf: now) == .missed {
                                confirmRetroactive = occ
                            }
                        }
                    }
                }
            }
        }
        .alert(
            "Mark as Taken?",
            isPresented: Binding(
                get: { confirmRetroactive != nil },
                set: { if !$0 { confirmRetroactive = nil } }
            )
        ) {
            Button("Mark Taken") {
                if let occ = confirmRetroactive { retroactiveComplete(occ) }
                confirmRetroactive = nil
            }
            Button("Cancel", role: .cancel) { confirmRetroactive = nil }
        } message: {
            Text("This dose was scheduled in the past. It will be marked as taken late.")
        }
    }

    private func rowAccessibilityLabel(_ occ: ScheduledOccurrence) -> String {
        var parts: [String] = [occ.prescription.name]
        if occ.prescription.isArchived { parts.append("archived") }
        parts.append(occ.effectiveStatus(asOf: now).label)
        if let completedAt = occ.doseLog?.completedAt {
            parts.append("taken at \(completedAt.formatted(date: .omitted, time: .shortened))")
        } else {
            parts.append("scheduled for \(occ.scheduledDate.formatted(date: .omitted, time: .shortened))")
        }
        if let note = occ.doseLog?.noteText, !note.isEmpty { parts.append("note: \(note)") }
        if occ.doseLog?.photoFilename != nil { parts.append("photo attached") }
        return parts.joined(separator: ", ")
    }

    private func statusView(for occ: ScheduledOccurrence) -> some View {
        StatusStamp(status: occ.effectiveStatus(asOf: now), scheduledDate: occ.scheduledDate, now: now)
    }

    private func retroactiveComplete(_ occ: ScheduledOccurrence) {
        if let existing = occ.doseLog {
            existing.status = .taken
            existing.completedAt = Date()
        } else {
            let log = DoseLog(
                prescriptionId: occ.prescription.id,
                scheduledDate: occ.scheduledDate,
                status: .taken,
                completedAt: Date()
            )
            context.insert(log)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
