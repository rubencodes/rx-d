import WidgetKit
import Foundation

struct DoseEntry: TimelineEntry {
    let date: Date
    let items: [DoseItem]    // today's doses (for selected prescription, or all if none selected)
    let streak: Int

    static func placeholder() -> DoseEntry {
        DoseEntry(
            date: Date(),
            items: [
                DoseItem(prescriptionId: UUID(), name: "Morning Vitamins",
                         colorHex: "#5B8DEF", scheduledDate: Date(), status: .pending)
            ],
            streak: 3
        )
    }
}
