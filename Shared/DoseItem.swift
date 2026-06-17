import Foundation

struct DoseItem: Identifiable {
    let prescriptionId: UUID
    let name: String
    let colorHex: String
    let scheduledDate: Date
    let status: DoseStatus

    var id: String { "\(prescriptionId)-\(scheduledDate.timeIntervalSince1970)" }
}
