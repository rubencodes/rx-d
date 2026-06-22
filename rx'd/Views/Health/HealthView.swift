import Charts
import SwiftData
import SwiftUI

struct HealthView: View {
    @Query(filter: #Predicate<Prescription> { !$0.isArchived })
    private var prescriptions: [Prescription]
    @Query private var allLogs: [DoseLog]

    @State private var connected = HealthView.initialConnected()
    @State private var data: [HealthKitService.Vital: [Date: Double]] = [:]
    @State private var loading = false
    @State private var showImport = false

    private let dayCount = 14
    private let cal = Calendar.current

    private static func initialConnected() -> Bool {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--health-connected") { return true }
        #endif
        return SharedDefaults.shared.healthConnected
    }

    private static var debugShowImport: Bool {
        #if DEBUG
            return ProcessInfo.processInfo.arguments.contains("--show-import")
        #else
            return false
        #endif
    }

    private var withData: [HealthKitService.Vital] {
        HealthKitService.Vital.allCases.filter { !(data[$0] ?? [:]).isEmpty }
    }

    private var withoutData: [HealthKitService.Vital] {
        HealthKitService.Vital.allCases.filter { (data[$0] ?? [:]).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !connected {
                        connectPrompt
                    } else {
                        importButton

                        if loading {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            // Charts with data first, legend shown once.
                            if !withData.isEmpty {
                                legend
                                ForEach(withData) { chartCard(for: $0) }
                            } else {
                                noDataHero
                            }
                            // Data-less vitals, collapsed.
                            if !withoutData.isEmpty {
                                RuledHeader(title: "No recent data")
                                    .padding(.top, 4)
                                ForEach(withoutData) { collapsedRow($0) }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .layoutWide)
            .frame(maxWidth: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Health")
            .task { await load() }
            .sheet(isPresented: $showImport) { ImportMedicationsView() }
            .onAppear { if HealthView.debugShowImport { showImport = true } }
        }
    }

    // MARK: - Connect prompt

    private var connectPrompt: some View {
        VStack(spacing: 16) {
            PillBuddy(mood: .content, topColor: Theme.accent, size: 96)
                .padding(.top, 24)
                .padding(.bottom, 12)
            Text("Connect Apple Health")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text("See how your vitals — blood pressure, glucose, weight and more — track against the days you take your doses.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkFaded)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Connect Apple Health") {
                Task {
                    await HealthKitService.requestAuthorization()
                    connected = true
                    await load()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.accent)
            .disabled(!HealthKitService.isAvailable)
            if !HealthKitService.isAvailable {
                Text("Health data isn't available on this device.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaded)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Import entry point

    private var importButton: some View {
        Button { showImport = true } label: {
            HStack(spacing: 12) {
                RxMonogram(size: 30, color: Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Import from Apple Health").font(.headline).foregroundStyle(Theme.ink)
                    Text("Copy medications you've set up in Health")
                        .font(.caption).foregroundStyle(Theme.inkFaded)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkFaded)
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart card (has data)

    private func chartCard(for vital: HealthKitService.Vital) -> some View {
        LabelCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(vital.title) vs. adherence")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkFaded)
                chart(for: vital)
                    .frame(height: 200)
            }
            .padding(16)
        }
    }

    private func chart(for vital: HealthKitService.Vital) -> some View {
        Chart(points(for: vital)) { point in
            if let value = point.value {
                LineMark(x: .value("Day", point.date), y: .value(vital.title, value))
                    .foregroundStyle(Theme.inkFaded.opacity(0.5))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Day", point.date), y: .value(vital.title, value))
                    .foregroundStyle(point.color)
                    .symbolSize(120)
            }
        }
        .chartYAxisLabel(vital.unitLabel)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }

    // MARK: - Collapsed row (no data)

    private func collapsedRow(_ vital: HealthKitService.Vital) -> some View {
        LabelCard {
            HStack {
                Text(vital.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkFaded)
                Spacer()
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaded.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var noDataHero: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .font(.largeTitle)
                .foregroundStyle(Theme.inkFaded)
            Text("No Health data yet")
                .font(.headline).foregroundStyle(Theme.ink)
            Text("Add readings in the Health app and they'll chart against your adherence here.")
                .font(.caption).foregroundStyle(Theme.inkFaded)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(Theme.taken, "All taken")
            legendDot(Theme.snoozed, "Partial")
            legendDot(Theme.missed, "Missed")
            legendDot(Theme.inkFaded.opacity(0.4), "No doses")
        }
        .font(.caption2)
        .foregroundStyle(Theme.inkFaded)
        .frame(maxWidth: .infinity)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: - Data

    private struct DayPoint: Identifiable {
        let date: Date
        let value: Double?
        let color: Color
        var id: Date { date }
    }

    private func points(for vital: HealthKitService.Vital) -> [DayPoint] {
        let values = data[vital] ?? [:]
        let today = cal.startOfDay(for: Date())
        return (0 ..< dayCount).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            return DayPoint(date: day, value: values[day], color: adherenceColor(for: day))
        }
    }

    private func adherenceColor(for day: Date) -> Color {
        let a = DayAdherence.compute(prescriptions: prescriptions, logs: allLogs, day: day, now: Date())
        return a.total == 0 ? Theme.inkFaded.opacity(0.4) : a.color
    }

    private func load() async {
        guard connected else { return }
        loading = true
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(dayCount - 1), to: today)!
        let end = cal.date(byAdding: .day, value: 1, to: today)!

        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--fake-vitals") {
                var result: [HealthKitService.Vital: [Date: Double]] = [:]
                for vital in [HealthKitService.Vital.systolicBP, .restingHeartRate] {
                    var series: [Date: Double] = [:]
                    let base: Double = vital == .systolicBP ? 122 : 64
                    for offset in 0 ..< dayCount {
                        let day = cal.date(byAdding: .day, value: -offset, to: today)!
                        series[day] = base + Double((offset * 7) % 18) - 6
                    }
                    result[vital] = series
                }
                data = result
                loading = false
                return
            }
        #endif

        var result: [HealthKitService.Vital: [Date: Double]] = [:]
        for vital in HealthKitService.Vital.allCases {
            result[vital] = await HealthKitService.dailyValues(for: vital, from: start, to: end)
        }
        data = result
        loading = false
    }
}
