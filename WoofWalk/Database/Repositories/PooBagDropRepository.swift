import SwiftData
import Foundation

@MainActor
class PooBagDropRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getActiveBagDrops() throws -> [PooBagDropEntity] {
        let descriptor = FetchDescriptor<PooBagDropEntity>(
            predicate: #Predicate { $0.isCollected == false },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getCollectedBagDrops() throws -> [PooBagDropEntity] {
        var descriptor = FetchDescriptor<PooBagDropEntity>(
            predicate: #Predicate { $0.isCollected == true },
            sortBy: [SortDescriptor(\.collectedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        return try modelContext.fetch(descriptor)
    }

    func insert(_ drop: PooBagDropEntity) throws {
        modelContext.insert(drop)
        try modelContext.save()
    }

    func markAsCollected(id: String, collectedAt: Date = Date()) throws {
        let descriptor = FetchDescriptor<PooBagDropEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let drop = try modelContext.fetch(descriptor).first {
            drop.isCollected = true
            drop.collectedAt = collectedAt
            try modelContext.save()
        }
    }

    func delete(id: String) throws {
        let descriptor = FetchDescriptor<PooBagDropEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let drop = try modelContext.fetch(descriptor).first {
            modelContext.delete(drop)
            try modelContext.save()
        }
    }

    func deleteOldCollected(cutoffTime: Date) throws {
        let descriptor = FetchDescriptor<PooBagDropEntity>(
            predicate: #Predicate { drop in
                drop.isCollected == true && drop.collectedAt ?? Date.distantPast < cutoffTime
            }
        )
        let oldDrops = try modelContext.fetch(descriptor)
        for drop in oldDrops {
            modelContext.delete(drop)
        }
        try modelContext.save()
    }
}
