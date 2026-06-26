import SwiftData
import SwiftUI
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
    @State private var store = StoreManager.shared
    @State private var showPaywall = false

    @Query(filter: #Predicate<Prescription> { !$0.isArchived })
    private var activePrescriptions: [Prescription]

    @State private var name = ""
    @State private var scheduledTime = Date()
    @State private var isDaily = true
    @State private var selectedDays: Set<Weekday> = []
    @State private var color = "#5B8DEF"
    @State private var notes = ""
    @State private var followUpEnabled = true
    @State private var followUpInterval: TimeInterval = 7200
    @State private var repeatUntilDone = false
    @State private var timeSensitive = true
    @State private var isSaving = false

    // Medications found in Apple Health that aren't imported yet, suggested when adding.
    // Stored as plain strings so this view stays available below iOS 26 (the Health
    // Medications API, and HealthKitService, are iOS 26+).
    @State private var healthSuggestions: [MedSuggestion] = []
    @State private var selectedHealthConceptID: String?

    private let notificationCenter: UNUserNotificationCenter = .current()
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
        ("4 hours", 14400),
    ]

    private var currentIntervalLabel: String {
        followUpOptions.first { $0.seconds == followUpInterval }?.label ?? "a while"
    }

    private var followUpFooter: String {
        if !followUpEnabled {
            return "Only the reminder at the scheduled time fires — no follow-up."
        }
        return repeatUntilDone
            ? "Nudges you every \(currentIntervalLabel) until you mark the dose taken (capped at a few reminders)."
            : "Reminds you once if the dose still hasn't been taken."
    }

    let colorOptions = [
        "#5B8DEF", "#FF6B6B", "#51CF66", "#FAB005",
        "#CC5DE8", "#339AF0", "#FF922B", "#20C997",
    ]

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing, !healthSuggestions.isEmpty {
                    Section {
                        ForEach(healthSuggestions) { suggestion in
                            Button {
                                Task { await applySuggestion(suggestion) }
                            } label: {
                                HStack(spacing: 12) {
                                    RxMonogram(size: 26, color: Theme.accent)
                                    Text(suggestion.name).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: selectedHealthConceptID == suggestion.archivedID
                                        ? "checkmark.circle.fill" : "arrow.down.circle")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    } header: {
                        Text("From Apple Health")
                    } footer: {
                        Text("Tap a medication you take to fill in its details.")
                    }
                }

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
                .animation(.spring, value: isDuplicateName)

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
                .animation(.spring, value: isDaily)

                Section {
                    if followUpEnabled {
                        Picker(repeatUntilDone ? "Every" : "After", selection: $followUpInterval) {
                            ForEach(followUpOptions, id: \.seconds) { opt in
                                Text(opt.label).tag(opt.seconds)
                            }
                        }
                        .pickerStyle(.menu)
                        if store.isPro {
                            Toggle("Repeat until taken", isOn: $repeatUntilDone)
                        } else {
                            Button { showPaywall = true } label: {
                                HStack {
                                    Text("Repeat until taken").foregroundStyle(Theme.ink)
                                    Spacer()
                                    Label("Pro", systemImage: "lock.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.gold)
                                }
                            }
                        }
                    } else {
                        Text(followUpFooter)
                            .font(.footnote)
                            .foregroundStyle(.placeholder)
                    }
                } header: {
                    Toggle(isOn: $followUpEnabled) {
                        Text("Follow-up Reminder")
                            .fontWeight(.semibold)
                    }
                } footer: {
                    if followUpEnabled {
                        Text(followUpFooter)
                    }
                }
                .animation(.spring, value: followUpEnabled)

                Section {
                    Toggle("Time-Sensitive Alerts", isOn: $timeSensitive)
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("Time-sensitive alerts break through Focus and Do Not Disturb. They don't override the silent switch.")
                }
                .animation(.spring, value: timeSensitive)

                Section("Color") {
                    colorPicker
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3 ... 6)
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
            .task { await loadHealthSuggestions() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
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
        followUpEnabled = p.followUpEnabled
        followUpInterval = p.followUpInterval
        repeatUntilDone = p.repeatRemindersUntilDone
        timeSensitive = p.timeSensitive
        switch p.frequency {
        case .daily:
            isDaily = true
        case let .weekly(days):
            isDaily = false
            selectedDays = days
        }
    }

    // Surface not-yet-imported Apple Health medications as suggestions (add mode only).
    // Querying never prompts — it returns results only if the user already granted
    // medication access via "Connect Apple Health", so this stays silent otherwise.
    private func loadHealthSuggestions() async {
        guard !isEditing else { return }
        if #available(iOS 26, *) {
            guard HealthKitService.isAvailable, SharedDefaults.shared.healthConnected else { return }
            let meds = await HealthKitService.fetchMedications()
            let imported = Set(activePrescriptions.compactMap(\.healthConceptID))
            healthSuggestions = meds
                .filter { !imported.contains($0.archivedID) }
                .map { MedSuggestion(name: $0.name, archivedID: $0.archivedID) }
        }
    }

    // Prefill the form from a Health medication — name, the schedule inferred from its
    // dose-event history, and the link used later to mirror Health-logged doses.
    private func applySuggestion(_ suggestion: MedSuggestion) async {
        name = suggestion.name
        color = "#2E6B5E"
        selectedHealthConceptID = suggestion.archivedID
        if #available(iOS 26, *), let concept = HealthKitService.unarchiveConcept(suggestion.archivedID) {
            let schedules = await HealthKitService.inferredSchedules(for: concept)
            if let s = schedules.first {
                scheduledTime = Calendar.current.date(
                    bySettingHour: s.hour, minute: s.minute, second: 0, of: Date()
                ) ?? scheduledTime
                if s.isDaily {
                    isDaily = true
                } else {
                    isDaily = false
                    selectedDays = Set(s.weekdays.compactMap { Weekday(rawValue: $0) })
                }
            }
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
            p.followUpEnabled = followUpEnabled
            p.followUpInterval = followUpInterval
            p.repeatRemindersUntilDone = repeatUntilDone
            p.timeSensitive = timeSensitive
        } else {
            let p = Prescription(
                name: name,
                scheduledTime: scheduledTime,
                frequency: frequency,
                color: color,
                notes: notes.isEmpty ? nil : notes,
                followUpEnabled: followUpEnabled,
                followUpInterval: followUpInterval,
                repeatRemindersUntilDone: repeatUntilDone,
                timeSensitive: timeSensitive
            )
            p.healthConceptID = selectedHealthConceptID
            context.insert(p)
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        if requestsNotificationPermission {
            // Lazy permission request on first add from the normal (sheet) flow.
            Task {
                let settings = await notificationCenter.notificationSettings()
                if settings.authorizationStatus == .notDetermined {
                    _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
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

// A not-yet-imported Apple Health medication, reduced to plain strings so the add
// screen can hold it without depending on the iOS 26-only Health Medications types.
private struct MedSuggestion: Identifiable {
    let name: String
    let archivedID: String
    var id: String { archivedID }
}
