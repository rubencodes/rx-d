import SwiftUI
import SwiftData
import WidgetKit

struct ScheduleView: View {
    @Query(filter: #Predicate<Prescription> { !$0.isArchived },
           sort: \Prescription.createdAt)
    private var active: [Prescription]

    @Query(filter: #Predicate<Prescription> { $0.isArchived },
           sort: \Prescription.archivedAt)
    private var archived: [Prescription]

    @Environment(\.modelContext) private var context
    @State private var showAdd = false
    @State private var editTarget: Prescription?
    @State private var deleteTarget: Prescription?
    @State private var archivedDetail: Prescription?

    var body: some View {
        NavigationStack {
            Group {
                if active.isEmpty && archived.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(active) { prescription in
                                prescriptionRow(prescription)
                            }
                        } header: {
                            RuledHeader(title: "Active").textCase(nil).padding(.bottom, 4)
                        }

                        if !archived.isEmpty {
                            Section {
                                ForEach(archived) { prescription in
                                    archivedRow(prescription)
                                }
                            } header: {
                                RuledHeader(title: "Archived").textCase(nil).padding(.bottom, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Schedule")
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--show-delete-alert") {
                    deleteTarget = archived.first
                }
                if ProcessInfo.processInfo.arguments.contains("--show-archived-detail") {
                    archivedDetail = archived.first
                }
                #endif
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditPrescriptionView()
            }
            .sheet(item: $editTarget) { p in
                AddEditPrescriptionView(prescription: p)
            }
            .sheet(item: $archivedDetail) { p in
                ArchivedDetailView(
                    prescription: p,
                    onRestore: { restore(p) },
                    onDelete: { deletePermanently(p) }
                )
            }
            .alert(
                "Delete Permanently?",
                isPresented: Binding(
                    get: { deleteTarget != nil },
                    set: { if !$0 { deleteTarget = nil } }
                ),
                presenting: deleteTarget
            ) { p in
                Button("Delete", role: .destructive) { deletePermanently(p) }
                Button("Cancel", role: .cancel) {}
            } message: { p in
                Text("This permanently deletes “\(p.name)” and all of its dose history, notes, and photos. This can’t be undone.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            PillBuddy(mood: .content, topColor: Theme.accent, size: 96)
            Text("No prescriptions yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text("Tap + to add your first prescription.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkFaded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cardRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LabelCard { content().padding(14) }
            .listRowInsets(.init(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func prescriptionRow(_ p: Prescription) -> some View {
        cardRow {
            HStack(spacing: 12) {
                RxMonogram(size: 32, color: Color(hex: p.color))
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.headline).foregroundStyle(Theme.ink)
                    HStack(spacing: 6) {
                        Text(frequencyLabel(p).uppercased())
                            .font(.caption2.weight(.semibold)).tracking(1)
                            .foregroundStyle(Theme.inkFaded)
                        if p.healthConceptID != nil {
                            AppleHealthBadge()
                        }
                    }
                }
                Spacer()
                Text(p.scheduledTime.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editTarget = p }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { archive(p) } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button { editTarget = p } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Theme.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(p.name), \(frequencyLabel(p)), \(p.scheduledTime.formatted(date: .omitted, time: .shortened))")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens editor")
        .accessibilityActions {
            Button("Edit") { editTarget = p }
            Button("Archive") { archive(p) }
        }
    }

    private func archivedRow(_ p: Prescription) -> some View {
        cardRow {
            HStack(spacing: 12) {
                RxMonogram(size: 32, color: Theme.inkFaded)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.headline).italic().foregroundStyle(Theme.inkFaded)
                    Text("ARCHIVED")
                        .font(.caption2.weight(.semibold)).tracking(1.5)
                        .foregroundStyle(Theme.inkFaded.opacity(0.7))
                }
                Spacer()
                Button("Restore") { restore(p) }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { archivedDetail = p }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deleteTarget = p } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(p.name), archived")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens history")
        .accessibilityActions {
            Button("View history") { archivedDetail = p }
            Button("Restore") { restore(p) }
            Button("Delete permanently") { deleteTarget = p }
        }
    }

    private func archive(_ p: Prescription) {
        p.isArchived = true
        p.archivedAt = Date()
        NotificationService.cancelNotifications(for: p)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func restore(_ p: Prescription) {
        p.isArchived = false
        p.archivedAt = nil
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        // rescheduleAll() clears ALL pending notifications first, so it must be given
        // every active prescription (plus logs) — not just the restored one — or the
        // others' reminders would be wiped until the next reschedule pass.
        Task {
            let active = (try? context.fetch(
                FetchDescriptor<Prescription>(predicate: #Predicate { !$0.isArchived })
            )) ?? []
            let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
            await NotificationService.rescheduleAll(prescriptions: active, logs: logs)
        }
    }

    // Hard delete: removes the prescription and all of its associated data.
    // There is no SwiftData relationship (logs join by prescriptionId), so we
    // delete the logs and their photo files explicitly.
    private func deletePermanently(_ p: Prescription) {
        NotificationService.cancelNotifications(for: p)

        let pid = p.id
        let logs = (try? context.fetch(
            FetchDescriptor<DoseLog>(predicate: #Predicate { $0.prescriptionId == pid })
        )) ?? []
        for log in logs {
            if let filename = log.photoFilename { PhotoStore.delete(filename) }
            context.delete(log)
        }
        context.delete(p)
        try? context.save()

        deleteTarget = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func frequencyLabel(_ p: Prescription) -> String {
        switch p.frequency {
        case .daily:
            return "Daily"
        case .weekly(let days):
            let names = Weekday.allCases
                .filter { days.contains($0) }
                .map(\.shortName)
                .joined(separator: ", ")
            return names.isEmpty ? "Weekly" : names
        }
    }
}
