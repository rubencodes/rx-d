import WidgetKit
import AppIntents
import SwiftData
import Foundation

struct NextDoseControlProvider: ControlValueProvider {
    var previewValue: NextDoseValue {
        NextDoseValue(title: "Morning Vitamins", subtitle: "8:00 AM",
                      prescriptionId: "", scheduledDate: 0, hasDose: true)
    }

    func currentValue() async throws -> NextDoseValue {
        await fetchNext()
    }

    @MainActor
    private func fetchNext() -> NextDoseValue {
        let now = Date()
        let cal = Calendar.current
        guard let container = try? ModelContainerFactory.makeSharedContainer() else {
            return NextDoseValue(title: "rx'd", subtitle: "", prescriptionId: "", scheduledDate: 0, hasDose: false)
        }
        let ctx = ModelContext(container)
        let prescriptions = (try? ctx.fetch(
            FetchDescriptor<Prescription>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let logs = (try? ctx.fetch(FetchDescriptor<DoseLog>())) ?? []

        var pending: [(Prescription, Date)] = []
        for p in prescriptions {
            for date in ScheduleService.occurrences(for: p, on: now) {
                let log = logs.first {
                    $0.prescriptionId == p.id &&
                    cal.isDate($0.scheduledDate, equalTo: date, toGranularity: .minute)
                }
                let status = log?.status ?? (date <= now ? .missed : .pending)
                if status == .pending { pending.append((p, date)) }
            }
        }
        pending.sort { $0.1 < $1.1 }

        guard let next = pending.first else {
            return NextDoseValue(title: "All caught up", subtitle: "", prescriptionId: "", scheduledDate: 0, hasDose: false)
        }
        return NextDoseValue(
            title: next.0.name,
            subtitle: next.1.formatted(date: .omitted, time: .shortened),
            prescriptionId: next.0.id.uuidString,
            scheduledDate: next.1.timeIntervalSince1970,
            hasDose: true
        )
    }
}
