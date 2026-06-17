import SwiftUI
import SwiftData

// Lists medications the user set up in Apple Health and imports them as rx'd
// prescriptions (read-only copy; links via healthConceptID for dose-event mirroring).
struct ImportMedicationsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var prescriptions: [Prescription]

    @State private var medications: [HealthKitService.HealthMedication] = []
    @State private var loading = true

    private var importedIDs: Set<String> {
        Set(prescriptions.compactMap(\.healthConceptID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if loading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    } else if medications.isEmpty {
                        emptyState
                    } else {
                        Text("Pick medications to copy into rx'd. You can set times and reminders after importing.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkFaded)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(medications) { med in
                            row(med)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Import from Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await fetch() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            PillBuddy(mood: .sleepy, topColor: Theme.pending, size: 84)
                .padding(.top, 24)
            Text("No medications in Apple Health")
                .font(.headline).foregroundStyle(Theme.ink)
            Text("Add medications in the Health app, then come back to import them.")
                .font(.subheadline).foregroundStyle(Theme.inkFaded)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ med: HealthKitService.HealthMedication) -> some View {
        let isImported = importedIDs.contains(med.archivedID)
        return LabelCard {
            HStack(spacing: 12) {
                RxMonogram(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.name).font(.headline).foregroundStyle(Theme.ink)
                    if med.isArchived {
                        Text("ARCHIVED IN HEALTH")
                            .font(.caption2.weight(.semibold)).tracking(1)
                            .foregroundStyle(Theme.inkFaded)
                    }
                }
                Spacer()
                if isImported {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.taken)
                } else {
                    Button("Import") { Task { await importMed(med) } }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                }
            }
            .padding(14)
        }
    }

    private func fetch() async {
        loading = true
        await HealthKitService.requestMedicationAuthorization()
        medications = await HealthKitService.fetchMedications()
        loading = false
    }

    private func importMed(_ med: HealthKitService.HealthMedication) async {
        let cal = Calendar.current
        let schedules = await HealthKitService.inferredSchedules(for: med.conceptID)

        func makeTime(_ hour: Int, _ minute: Int) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }

        if schedules.isEmpty {
            // No scheduled dose history to learn from — sensible default.
            let p = Prescription(name: med.name, scheduledTime: makeTime(9, 0),
                                 frequency: .daily, color: "#2E6B5E")
            p.healthConceptID = med.archivedID
            context.insert(p)
        } else {
            // One prescription per distinct scheduled time, with the observed frequency.
            for schedule in schedules {
                let weekdays = Set(schedule.weekdays.compactMap { Weekday(rawValue: $0) })
                let frequency: Frequency = schedule.isDaily ? .daily : .weekly(days: weekdays)
                let p = Prescription(name: med.name, scheduledTime: makeTime(schedule.hour, schedule.minute),
                                     frequency: frequency, color: "#2E6B5E")
                p.healthConceptID = med.archivedID
                context.insert(p)
            }
        }
        try? context.save()
    }
}
