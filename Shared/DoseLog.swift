import Foundation
import SwiftData

@Model
final class DoseLog {
    // Inline default values on every stored property keep the schema CloudKit-compatible.
    // Doses join to their Prescription via the manual `prescriptionId` UUID (no relationship).
    var id: UUID = UUID()
    var prescriptionId: UUID = UUID()
    var scheduledDate: Date = Date()
    var completedAt: Date?
    var statusRaw: String = "pending"
    var snoozeCount: Int = 0
    var noteText: String?
    var photoFilename: String?
    // True when this log was mirrored from a dose the user logged in Apple Health.
    var isFromHealth: Bool = false

    init(
        prescriptionId: UUID,
        scheduledDate: Date,
        status: DoseStatus,
        completedAt: Date? = nil,
        snoozeCount: Int = 0,
        noteText: String? = nil,
        photoFilename: String? = nil,
        isFromHealth: Bool = false
    ) {
        self.id = UUID()
        self.prescriptionId = prescriptionId
        self.scheduledDate = scheduledDate
        self.statusRaw = status.rawValue
        self.completedAt = completedAt
        self.snoozeCount = snoozeCount
        self.noteText = noteText
        self.photoFilename = photoFilename
        self.isFromHealth = isFromHealth
    }

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
