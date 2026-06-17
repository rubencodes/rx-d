import SwiftData
import SwiftUI

// Read-only detail for an archived prescription: its info + full dose history,
// with Restore and permanent-Delete actions.
struct ArchivedDetailView: View {
    let prescription: Prescription
    let onRestore: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var logs: [DoseLog]
    @State private var showDeleteConfirm = false

    init(prescription: Prescription, onRestore: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.prescription = prescription
        self.onRestore = onRestore
        self.onDelete = onDelete
        let pid = prescription.id
        _logs = Query(
            filter: #Predicate<DoseLog> { $0.prescriptionId == pid },
            sort: \.scheduledDate, order: .reverse
        )
    }

    private var takenCount: Int { logs.filter { $0.status == .taken }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    infoCard

                    RuledHeader(title: "History")

                    if logs.isEmpty {
                        Text("No doses were ever logged.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkFaded)
                            .padding(.vertical, 24)
                    } else {
                        LabelCard {
                            VStack(spacing: 0) {
                                ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                                    if index > 0 { Divider().padding(.leading, 14) }
                                    historyRow(log)
                                }
                            }
                        }
                    }

                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Permanently", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.oxblood)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") { onRestore(); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Permanently?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { onDelete(); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes “\(prescription.name)” and all of its dose history, notes, and photos. This can’t be undone.")
            }
        }
    }

    private var infoCard: some View {
        LabelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    RxMonogram(size: 38, color: Color(hex: prescription.color))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prescription.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Text("ARCHIVED")
                            .font(.caption2.weight(.bold)).tracking(1.5)
                            .foregroundStyle(Theme.inkFaded)
                    }
                    Spacer()
                }
                Divider()
                infoRow("Schedule", frequencyLabel)
                infoRow("Time", prescription.scheduledTime.formatted(date: .omitted, time: .shortened))
                infoRow("Doses taken", "\(takenCount) of \(logs.count) logged")
                if let archivedAt = prescription.archivedAt {
                    infoRow("Archived", archivedAt.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .padding(16)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.inkFaded)
            Spacer()
            Text(value).foregroundStyle(Theme.ink)
        }
        .font(.subheadline)
    }

    private func historyRow(_ log: DoseLog) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text(log.scheduledDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaded)
                if log.isFromHealth {
                    AppleHealthBadge()
                }
            }
            Spacer()
            StatusStamp(status: log.status, scheduledDate: log.scheduledDate)
        }
        .padding(14)
    }

    private var frequencyLabel: String {
        switch prescription.frequency {
        case .daily: return "Daily"
        case let .weekly(days):
            let names = Weekday.allCases.filter { days.contains($0) }.map(\.shortName).joined(separator: ", ")
            return names.isEmpty ? "Weekly" : names
        }
    }
}
