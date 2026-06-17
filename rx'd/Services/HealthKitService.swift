import Foundation
import HealthKit
import SwiftData

// Wraps all Apple Health access. Reads only — rx'd never writes to Health.
// (The iOS 26 Medications API is read-only for dose events anyway.)
@MainActor
enum HealthKitService {
    static let store = HKHealthStore()
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Vitals we can correlate against adherence.
    enum Vital: String, CaseIterable, Identifiable {
        case weight, restingHeartRate, bloodGlucose, systolicBP, steps

        var id: String { rawValue }

        var title: String {
            switch self {
            case .weight:           "Weight"
            case .restingHeartRate: "Resting Heart Rate"
            case .bloodGlucose:     "Blood Glucose"
            case .systolicBP:       "Blood Pressure (Systolic)"
            case .steps:            "Steps"
            }
        }

        var unitLabel: String {
            switch self {
            case .weight:           "lb"
            case .restingHeartRate: "bpm"
            case .bloodGlucose:     "mg/dL"
            case .systolicBP:       "mmHg"
            case .steps:            "steps"
            }
        }

        var quantityType: HKQuantityType {
            switch self {
            case .weight:           HKQuantityType(.bodyMass)
            case .restingHeartRate: HKQuantityType(.restingHeartRate)
            case .bloodGlucose:     HKQuantityType(.bloodGlucose)
            case .systolicBP:       HKQuantityType(.bloodPressureSystolic)
            case .steps:            HKQuantityType(.stepCount)
            }
        }

        var unit: HKUnit {
            switch self {
            case .weight:           .pound()
            case .restingHeartRate: HKUnit(from: "count/min")
            case .bloodGlucose:     HKUnit(from: "mg/dL")
            case .systolicBP:       .millimeterOfMercury()
            case .steps:            .count()
            }
        }

        var isCumulative: Bool { self == .steps }
    }

    // Vitals read set (always safe to request).
    static func vitalReadTypes() -> Set<HKObjectType> {
        Set(Vital.allCases.map { $0.quantityType })
    }

    // Medication read types (iOS 26). Requesting these can raise an Objective-C
    // exception when unsupported/unentitled (e.g. the Simulator), so they're requested
    // separately and guarded — never folded into the always-on vitals request.
    static func medicationReadTypes() -> Set<HKObjectType> {
        [HKObjectType.userAnnotatedMedicationType(), HKObjectType.medicationDoseEventType()]
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: vitalReadTypes())
            SharedDefaults.shared.healthConnected = true
            return true
        } catch {
            return false
        }
    }

    // Medication types require PER-OBJECT read authorization (the user picks which
    // medications to share) — they're disallowed in the bulk requestAuthorization(),
    // which raises an uncatchable Obj-C exception. The per-object API returns a
    // catchable Swift error instead. Not supported on the Simulator, so skipped there.
    @discardableResult
    static func requestMedicationAuthorization() async -> Bool {
        guard isAvailable else { return false }
        #if targetEnvironment(simulator)
        return false
        #else
        do {
            for type in medicationReadTypes() {
                try await store.requestPerObjectReadAuthorization(for: type, predicate: nil)
            }
            return true
        } catch {
            return false
        }
        #endif
    }

    // Average (or summed, for steps) value per calendar day in [start, end].
    static func dailyValues(for vital: Vital, from start: Date, to end: Date) async -> [Date: Double] {
        guard isAvailable else { return [:] }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: start)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let options: HKStatisticsOptions = vital.isCumulative ? .cumulativeSum : .discreteAverage

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: vital.quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                var out: [Date: Double] = [:]
                results?.enumerateStatistics(from: anchor, to: end) { stat, _ in
                    let quantity = vital.isCumulative ? stat.sumQuantity() : stat.averageQuantity()
                    if let quantity {
                        out[cal.startOfDay(for: stat.startDate)] = quantity.doubleValue(for: vital.unit)
                    }
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
    }

    // MARK: - Medications (read-only)

    struct HealthMedication: Identifiable {
        let conceptID: HKHealthConceptIdentifier
        let archivedID: String
        let name: String
        let isArchived: Bool
        var id: String { archivedID }
    }

    // Archive/unarchive HKHealthConceptIdentifier (it has no plain string key) so we can
    // persist the link on a Prescription and match dose events later.
    static func archive(_ id: HKHealthConceptIdentifier) -> String? {
        try? NSKeyedArchiver
            .archivedData(withRootObject: id, requiringSecureCoding: true)
            .base64EncodedString()
    }

    static func unarchiveConcept(_ string: String) -> HKHealthConceptIdentifier? {
        guard let data = Data(base64Encoded: string) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: HKHealthConceptIdentifier.self, from: data)
    }

    // The user's medications as set up in Apple Health.
    static func fetchMedications() async -> [HealthMedication] {
        guard isAvailable else { return [] }
        return await withCheckedContinuation { continuation in
            var collected: [HealthMedication] = []
            var resumed = false
            let query = HKUserAnnotatedMedicationQuery(predicate: nil, limit: HKObjectQueryNoLimit) { _, medication, done, _ in
                if let medication {
                    let concept = medication.medication
                    if let archived = archive(concept.identifier) {
                        collected.append(HealthMedication(
                            conceptID: concept.identifier,
                            archivedID: archived,
                            name: medication.nickname ?? concept.displayText,
                            isArchived: medication.isArchived
                        ))
                    }
                }
                if done, !resumed {
                    resumed = true
                    continuation.resume(returning: collected)
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Schedule inference (from scheduled dose events)

    struct InferredSchedule {
        let hour: Int
        let minute: Int
        let weekdays: Set<Int>          // Calendar weekday values 1...7
        var isDaily: Bool { weekdays.count >= 7 }
    }

    // Derives a medication's schedule from its scheduled dose events: distinct
    // times-of-day, each with the set of weekdays it occurs on.
    static func inferredSchedules(for concept: HKHealthConceptIdentifier, daysBack: Int = 60) async -> [InferredSchedule] {
        guard isAvailable else { return [] }
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -daysBack, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let type = HKObjectType.medicationDoseEventType()

        let events: [HKMedicationDoseEvent] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKMedicationDoseEvent]) ?? [])
            }
            store.execute(query)
        }

        var byTime: [Int: Set<Int>] = [:]   // key = hour*60+minute → weekdays
        for event in events {
            guard event.scheduleType == .schedule,
                  event.medicationConceptIdentifier.isEqual(concept),
                  let date = event.scheduledDate else { continue }
            let comps = cal.dateComponents([.hour, .minute, .weekday], from: date)
            let key = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            byTime[key, default: []].insert(comps.weekday ?? 1)
        }
        return byTime.keys.sorted().map { key in
            InferredSchedule(hour: key / 60, minute: key % 60, weekdays: byTime[key] ?? [])
        }
    }

    // MARK: - Dose events (read-only) → mirror into local DoseLogs

    private static func mappedStatus(_ status: HKMedicationDoseEvent.LogStatus) -> DoseStatus? {
        switch status {
        case .taken:   return .taken
        case .snoozed: return .snoozed
        case .skipped: return .missed
        default:       return nil   // notInteracted / notLogged / notificationNotSent → ignore
        }
    }

    // Pull dose events the user logged in Apple Health and mirror them into our DoseLog
    // store for any prescription linked to a Health medication. One-directional
    // (Health → rx'd); we can't write dose events back to Health.
    @discardableResult
    static func mirrorDoseEvents(into context: ModelContext, daysBack: Int = 30) async -> Int {
        guard isAvailable else { return 0 }

        let prescriptions = (try? context.fetch(FetchDescriptor<Prescription>())) ?? []
        let linked: [(Prescription, HKHealthConceptIdentifier)] = prescriptions.compactMap { p in
            guard let stored = p.healthConceptID, let concept = unarchiveConcept(stored) else { return nil }
            return (p, concept)
        }
        guard !linked.isEmpty else { return 0 }

        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -daysBack, to: end)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let type = HKObjectType.medicationDoseEventType()

        let events: [HKMedicationDoseEvent] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKMedicationDoseEvent]) ?? [])
            }
            store.execute(query)
        }

        let existing = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
        var changed = 0
        for event in events {
            guard let status = mappedStatus(event.logStatus),
                  let date = event.scheduledDate ?? (event.startDate as Date?)
            else { continue }

            // A medication can map to several prescriptions (one per scheduled time).
            // Route the event to the one whose time-of-day is closest.
            let candidates = linked.filter { $0.1.isEqual(event.medicationConceptIdentifier) }
            guard !candidates.isEmpty else { continue }
            let eventMinutes = minutesOfDay(date, cal)
            let prescription = candidates.min {
                timeDistance(minutesOfDay($0.0.scheduledTime, cal), eventMinutes) <
                timeDistance(minutesOfDay($1.0.scheduledTime, cal), eventMinutes)
            }!.0

            if let log = existing.first(where: {
                $0.prescriptionId == prescription.id &&
                cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute)
            }) {
                if log.status != status || !log.isFromHealth {
                    log.status = status
                    log.isFromHealth = true
                    changed += 1
                }
            } else {
                context.insert(DoseLog(
                    prescriptionId: prescription.id,
                    scheduledDate: date,
                    status: status,
                    completedAt: status == .taken ? date : nil,
                    isFromHealth: true
                ))
                changed += 1
            }
        }
        if changed > 0 { try? context.save() }
        return changed
    }

    private static func minutesOfDay(_ date: Date, _ cal: Calendar) -> Int {
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    // Circular distance in minutes (so 23:55 is close to 00:05).
    private static func timeDistance(_ a: Int, _ b: Int) -> Int {
        let diff = abs(a - b)
        return min(diff, 1440 - diff)
    }
}
