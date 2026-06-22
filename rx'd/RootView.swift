import SwiftData
import SwiftUI
import WidgetKit

// Handles the onboarding gate, the Control Center confirmation alert, and the
// scene-active reschedule / auto-miss pass.
struct RootView: View {
    let container: ModelContainer
    @State private var showOnboarding = !SharedDefaults.shared.hasCompletedOnboarding
    @State private var doseToConfirm: PendingDose?

    #if DEBUG
        @State private var showDebugPaywall =
            ProcessInfo.processInfo.arguments.contains("--show-paywall")
    #endif

    var body: some View {
        Group {
            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--widget-gallery") {
                    WidgetGalleryView()
                } else if showOnboarding {
                    OnboardingFlow(onComplete: { showOnboarding = false })
                } else {
                    mainContent
                }
            #else
                if showOnboarding {
                    OnboardingFlow(onComplete: { showOnboarding = false })
                } else {
                    mainContent
                }
            #endif
        }
        .task {
            #if DEBUG
                if DebugSeed.isRequested {
                    DebugSeed.run(context: ModelContext(container))
                    // Keep onboarding visible when explicitly testing an onboarding step.
                    if !ProcessInfo.processInfo.arguments.contains("--onboarding-step") {
                        showOnboarding = false
                    }
                }
            #endif
        }
        // Central safety net: any SwiftData save (add/edit/archive/delete/mark/etc.)
        // refreshes the widgets, so they always reflect the current data.
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        // Confirmation requested by the "Next Dose" Control Center control.
        .task { checkPendingConfirmation() }
        .onScenePhaseActive { checkPendingConfirmation() }
        #if DEBUG
        .sheet(isPresented: $showDebugPaywall) { PaywallView() }
        #endif
        .alert(
            "Take Dose?",
            isPresented: Binding(get: { doseToConfirm != nil },
                                 set: { if !$0 { doseToConfirm = nil } }),
            presenting: doseToConfirm
        ) { dose in
            Button("Mark Taken") { confirmTaken(dose) }
            Button("Cancel", role: .cancel) { doseToConfirm = nil }
        } message: { dose in
            Text("Mark “\(dose.name)” as taken?")
        }
    }

    @ViewBuilder private var mainContent: some View {
        RootTabView()
            .onScenePhaseActive {
                Task { await rescheduleAndAutoMiss() }
            }
    }

    private func checkPendingConfirmation() {
        #if DEBUG
            if SharedDefaults.shared.pendingDoseConfirmation == nil,
               ProcessInfo.processInfo.arguments.contains("--confirm-dose")
            {
                SharedDefaults.shared.pendingDoseConfirmation =
                    "\(UUID())|\(Date().timeIntervalSince1970)|Evening Magnesium"
            }
        #endif
        guard let raw = SharedDefaults.shared.pendingDoseConfirmation else { return }
        SharedDefaults.shared.pendingDoseConfirmation = nil
        let parts = raw.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3, let pid = UUID(uuidString: parts[0]), let interval = Double(parts[1]) else { return }
        doseToConfirm = PendingDose(prescriptionId: pid,
                                    date: Date(timeIntervalSince1970: interval),
                                    name: parts[2])
    }

    private func confirmTaken(_ dose: PendingDose) {
        let context = ModelContext(container)
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
        if let existing = logs.first(where: {
            $0.prescriptionId == dose.prescriptionId &&
                Calendar.current.isDate($0.scheduledDate, equalTo: dose.date, toGranularity: .minute)
        }) {
            existing.status = .taken
            existing.completedAt = Date()
        } else {
            context.insert(DoseLog(prescriptionId: dose.prescriptionId, scheduledDate: dose.date,
                                   status: .taken, completedAt: Date()))
        }
        try? context.save()
        doseToConfirm = nil
        // Clear any pending reminders for this occurrence now that it's taken.
        NotificationService.cancelOccurrence(prescriptionId: dose.prescriptionId,
                                             scheduledDate: dose.date)
        WidgetCenter.shared.reloadAllTimelines()

        if #available(iOS 18, *) {
            ControlCenter.shared.reloadControls(ofKind: "codes.ruben.rx-d.NextDose")
        }
    }

    private func rescheduleAndAutoMiss() async {
        let context = ModelContext(container)
        do {
            try MissedDoseService.runAutoMissPass(context: context)
        } catch {
            print("Auto-miss pass failed: \(error)")
        }
        // Mirror any doses the user logged in Apple Health (read-only Health → rx'd).
        if SharedDefaults.shared.healthConnected, #available(iOS 26, *) {
            await HealthKitService.mirrorDoseEvents(into: context)
        }

        let prescriptions = (try? context.fetch(FetchDescriptor<Prescription>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
        _ = StreakService.computeAndCache(prescriptions: prescriptions, logs: logs)
        PhotoStore.cleanupOrphans(referencedFilenames: Set(logs.compactMap(\.photoFilename)))
        await NotificationService.rescheduleAll(prescriptions: prescriptions, logs: logs)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
