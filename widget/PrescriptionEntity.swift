import AppIntents

// AppEntity wrapping a Prescription, backed by the shared SwiftData store.
struct PrescriptionEntity: AppEntity {
    let id: UUID
    let name: String
    let colorHex: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Prescription" }
    static var defaultQuery = PrescriptionEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}
