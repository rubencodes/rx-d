import AppIntents
import SwiftData

struct PrescriptionEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [PrescriptionEntity] {
        try fetchAll().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [PrescriptionEntity] {
        try fetchAll()
    }

    // No default selection → an unconfigured widget shows all of today's doses,
    // not just the first prescription (which might not be scheduled today).
    func defaultResult() async -> PrescriptionEntity? { nil }

    private func fetchAll() throws -> [PrescriptionEntity] {
        let container = try ModelContainerFactory.makeSharedContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Prescription>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let prescriptions = try context.fetch(descriptor)
        return prescriptions.map {
            PrescriptionEntity(id: $0.id, name: $0.name, colorHex: $0.color)
        }
    }
}
