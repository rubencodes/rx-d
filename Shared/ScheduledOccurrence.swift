import Foundation

// View-level value type combining a prescription occurrence with its log (if any)
struct ScheduledOccurrence: Identifiable {
    let prescription: Prescription
    let scheduledDate: Date
    var doseLog: DoseLog?

    var id: String { "\(prescription.id)-\(scheduledDate.iso8601String)" }

    var effectiveStatus: DoseStatus { effectiveStatus(asOf: Date()) }

    // Status relative to a supplied "now" — lets time-driven views (TimelineView)
    // recompute consistently as the clock advances.
    func effectiveStatus(asOf now: Date) -> DoseStatus {
        doseLog?.status ?? (scheduledDate <= now ? .missed : .pending)
    }

    var isPast: Bool { scheduledDate < Date() }
}
