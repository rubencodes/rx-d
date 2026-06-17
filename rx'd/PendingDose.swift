import Foundation

// A dose awaiting in-app "Mark as taken?" confirmation (set by the Next Dose control).
struct PendingDose: Identifiable {
    let id = UUID()
    let prescriptionId: UUID
    let date: Date
    let name: String
}
