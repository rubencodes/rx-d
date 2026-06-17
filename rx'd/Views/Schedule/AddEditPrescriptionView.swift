import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit

struct AddEditPrescriptionView: View {
    var prescription: Prescription?
    // Onboarding embeds this view (not as a sheet). When `onSaved`/`onCancel` are set,
    // they advance the onboarding flow instead of calling dismiss(), and
    // `requestsNotificationPermission` is set false so the system prompt is deferred to
    // the dedicated "Allow Reminders" step.
    var onSaved: (() -> Void)?
    var onCancel: (() -> Void)?
    var requestsNotificationPermission: Bool = true
    var footerNote: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Prescription> { !$0.isArchived })
    private var activePrescriptions: [Prescription]

    @State private var name = ""
    @State private var scheduledTime = Date()
    @State private var isDaily = true
    @State private var selectedDays: Set<Weekday> = []
    @State private var color = "#5B8DEF"
    @State private var notes = ""
    @State private var followUpInterval: TimeInterval = 7200
    @State private var isSaving = false

    private var isEditing: Bool { prescription != nil }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isDaily || !selectedDays.isEmpty)
    }

    // Non-blocking: warns when another active prescription already uses this name.
    private var isDuplicateName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return false }
        return activePrescriptions.contains {
            $0.id != prescription?.id &&
            $0.name.trimmingCharacters(in: .whitespaces).lowercased() == trimmed
        }
    }

    let followUpOptions: [(label: String, seconds: TimeInterval)] = [
        ("30 min", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200),
        ("4 hours", 14400)
    ]

    let colorOptions = [
        "#5B8DEF", "#FF6B6B", "#51CF66", "#FAB005",
        "#CC5DE8", "#339AF0", "#FF922B", "#20C997"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Morning Vitamins", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    if isDuplicateName {
                        Label(
                            "You already have a prescription named \u{201C}\(name.trimmingCharacters(in: .whitespaces))\u{201D}. You can still save it.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                    }
                }

                Section("Schedule") {
                    DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)

                    Picker("Frequency", selection: $isDaily) {
                        Text("Daily").tag(true)
                        Text("Weekly").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if !isDaily {
                        weekdayPicker
                    }
                }

                Section("Follow-up Reminder") {
                    Picker("After", selection: $followUpInterval) {
                        ForEach(followUpOptions, id: \.seconds) { opt in
                            Text(opt.label).tag(opt.seconds)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Color") {
                    colorPicker
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let footerNote {
                    Section {} footer: {
                        Text(footerNote).font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Prescription" : "New Prescription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if let onCancel {
                        Button("Skip") { onCancel() }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || isSaving)
                }
            }
            .onAppear { populate() }
        }
    }

    private var weekdayPicker: some View {
        HStack {
            ForEach(Weekday.allCases) { day in
                let selected = selectedDays.contains(day)
                Button(day.shortName) {
                    if selected { selectedDays.remove(day) }
                    else { selectedDays.insert(day) }
                }
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8)) {
            ForEach(colorOptions, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(height: 32)
                    .overlay {
                        if hex == color {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { color = hex }
            }
        }
    }

    private func populate() {
        #if DEBUG
        if prescription == nil {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--prefill-name"), i + 1 < args.count {
                name = args[i + 1]
            }
        }
        #endif
        guard let p = prescription else { return }
        name = p.name
        scheduledTime = p.scheduledTime
        color = p.color
        notes = p.notes ?? ""
        followUpInterval = p.followUpInterval
        switch p.frequency {
        case .daily:
            isDaily = true
        case .weekly(let days):
            isDaily = false
            selectedDays = days
        }
    }

    private func save() {
        // Guard against re-entrancy: a rapid double-tap (or a Save that doesn't
        // immediately dismiss) must not insert duplicate prescriptions.
        guard !isSaving else { return }
        isSaving = true

        let frequency: Frequency = isDaily ? .daily : .weekly(days: selectedDays)

        if let p = prescription {
            p.name = name
            p.scheduledTime = scheduledTime
            p.frequency = frequency
            p.color = color
            p.notes = notes.isEmpty ? nil : notes
            p.followUpInterval = followUpInterval
        } else {
            let p = Prescription(
                name: name,
                scheduledTime: scheduledTime,
                frequency: frequency,
                color: color,
                notes: notes.isEmpty ? nil : notes,
                followUpInterval: followUpInterval
            )
            context.insert(p)
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        if requestsNotificationPermission {
            // Lazy permission request on first add from the normal (sheet) flow.
            Task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                if settings.authorizationStatus == .notDetermined {
                    try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])
                }
                let all = (try? context.fetch(
                    FetchDescriptor<Prescription>(predicate: #Predicate { !$0.isArchived })
                )) ?? []
                let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
                await NotificationService.rescheduleAll(prescriptions: all, logs: logs)
            }
        }
        // In onboarding (requestsNotificationPermission == false) the dedicated
        // "Allow Reminders" step requests permission, and the scene-active pass on
        // completion reschedules — so we don't prompt or schedule here.

        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }
}
