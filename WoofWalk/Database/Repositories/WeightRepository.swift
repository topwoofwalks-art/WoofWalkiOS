import SwiftData
import Foundation

@MainActor
class WeightRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func upsert(_ log: WeightLogEntity) throws {
        modelContext.insert(log)
        try modelContext.save()
    }

    func weights(_ dogId: String) throws -> [WeightLogEntity] {
        let descriptor = FetchDescriptor<WeightLogEntity>(
            predicate: #Predicate { $0.dogId == dogId },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getLatestWeight(_ dogId: String) throws -> WeightLogEntity? {
        var descriptor = FetchDescriptor<WeightLogEntity>(
            predicate: #Predicate { $0.dogId == dogId },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func deleteWeight(dogId: String, timestamp: Date) throws {
        let descriptor = FetchDescriptor<WeightLogEntity>(
            predicate: #Predicate { log in
                log.dogId == dogId && log.loggedAt == timestamp
            }
        )
        if let weight = try modelContext.fetch(descriptor).first {
            modelContext.delete(weight)
            try modelContext.save()
        }
    }
}
