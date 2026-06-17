import Foundation
import SwiftData

enum MissedDoseService {
    // Creates .missed DoseLog records for all past unlogged occurrences.
    // Call on sceneDidBecomeActive and from BGAppRefreshTask.
    static func runAutoMissPass(context: ModelContext) throws {
        let now = Date()
        let cutoff = now.addingTimeInterval(-60) // 1-minute grace

        let prescriptions = try context.fetch(FetchDescriptor<Prescription>())
        let logs = try context.fetch(FetchDescriptor<DoseLog>())

        let logIndex = Dictionary(
            grouping: logs,
            by: { "\($0.prescriptionId)-\($0.scheduledDate.isoDateString)-\($0.scheduledDate.hhmmString)" }
        )

        for prescription in prescriptions where !prescription.isArchived {
            let occurrences = ScheduleService.occurrences(
                for: prescription,
                from: prescription.createdAt,
                through: cutoff
            )
            for date in occurrences where date <= cutoff {
                let key = "\(prescription.id)-\(date.isoDateString)-\(date.hhmmString)"
                if logIndex[key] == nil {
                    let log = DoseLog(
                        prescriptionId: prescription.id,
                        scheduledDate: date,
                        status: .missed
                    )
                    context.insert(log)
                }
            }
        }
        try context.save()
    }
}
