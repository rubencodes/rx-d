import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query private var allLogs: [DoseLog]
    @Query private var allPrescriptions: [Prescription]
    @Environment(\.modelContext) private var context
    @State private var store = StoreManager.shared
    @State private var showPaywall = false

    @AppStorage("quietHoursEnabled") private var quietHoursEnabled = false
    @State private var iCloudSyncEnabled = SharedDefaults.shared.iCloudSyncEnabled
    @State private var quietStart = minutesToDate(SharedDefaults.shared.quietHoursStartMinutes)
    @State private var quietEnd = minutesToDate(SharedDefaults.shared.quietHoursEndMinutes)
    @State private var showExportOptions = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminders") {
                    Toggle("Quiet Hours", isOn: $quietHoursEnabled)
                        .onChange(of: quietHoursEnabled) { _, val in
                            SharedDefaults.shared.quietHoursEnabled = val
                        }
                    if quietHoursEnabled {
                        DatePicker("Start", selection: $quietStart, displayedComponents: .hourAndMinute)
                            .onChange(of: quietStart) { _, d in
                                SharedDefaults.shared.quietHoursStartMinutes = d.minutesSinceMidnight
                            }
                        DatePicker("End", selection: $quietEnd, displayedComponents: .hourAndMinute)
                            .onChange(of: quietEnd) { _, d in
                                SharedDefaults.shared.quietHoursEndMinutes = d.minutesSinceMidnight
                            }
                    }
                }

                Section {
                    Toggle("iCloud Sync", isOn: $iCloudSyncEnabled)
                        .onChange(of: iCloudSyncEnabled) { _, val in
                            SharedDefaults.shared.iCloudSyncEnabled = val
                        }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Syncs your prescriptions and doses across your devices. Requires the iCloud capability to be enabled. Restart the app after changing this.")
                }

                Section {
                    if store.isPro {
                        Label("Rex Pro unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.accent)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Unlock Rex Pro", systemImage: "sparkles")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(Theme.inkFaded)
                            }
                        }
                    }
                } header: {
                    Text("Rex Pro")
                } footer: {
                    if !store.isPro {
                        Text("Unlimited medications, repeat reminders, Apple Health, and CSV export.")
                    }
                }

                Section("Data") {
                    Button("Export CSV") {
                        if store.isPro { showExportOptions = true } else { showPaywall = true }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            RxMonogram(size: 34)
                            Text(verbatim: .appName)
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            Text("Take care of yourself.")
                                .font(.caption)
                                .foregroundStyle(Theme.inkFaded)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .layoutWide)
            .frame(maxWidth: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .tabNavigationTitle("Settings")
            .confirmationDialog("Export Scope", isPresented: $showExportOptions, titleVisibility: .visible) {
                Button("All Time") { export(scope: .allTime) }
                Button("This Month") { export(scope: .thisMonth) }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private enum ExportScope { case allTime, thisMonth }

    private func export(scope: ExportScope) {
        let filtered: [DoseLog]
        switch scope {
        case .allTime:
            filtered = allLogs
        case .thisMonth:
            let cal = Calendar.current
            let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
            filtered = allLogs.filter { $0.scheduledDate >= start }
        }

        let csv = ExportService.generateCSV(logs: filtered, prescriptions: allPrescriptions)
        let name = "rxd_export_\(Date().isoDateString).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showShareSheet = true
    }
}

private func minutesToDate(_ minutes: Int) -> Date {
    let cal = Calendar.current
    return cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
}
