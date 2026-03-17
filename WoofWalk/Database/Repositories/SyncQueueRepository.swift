#if false
import SwiftData
import Foundation

@MainActor
class SyncQueueRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getAllPending() throws -> [SyncQueueEntity] {
        let descriptor = FetchDescriptor<SyncQueueEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getPendingBatch() throws -> [SyncQueueEntity] {
        var descriptor = FetchDescriptor<SyncQueueEntity>(
            predicate: #Predicate { $0.retryCount < 3 },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = 50
        return try modelContext.fetch(descriptor)
    }

    func insert(_ item: SyncQueueEntity) throws -> Int64 {
        modelContext.insert(item)
        try modelContext.save()
        return item.id
    }

    func update(_ item: SyncQueueEntity) throws {
        try modelContext.save()
    }

    func delete(_ item: SyncQueueEntity) throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    func deleteById(_ id: Int64) throws {
        let descriptor = FetchDescriptor<SyncQueueEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let item = try modelContext.fetch(descriptor).first {
            modelContext.delete(item)
            try modelContext.save()
        }
    }

    func deleteByEntity(type: String, id: String) throws {
        let descriptor = FetchDescriptor<SyncQueueEntity>(
            predicate: #Predicate { entity in
                entity.entityType == type && entity.entityId == id
            }
        )
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func getPendingCount() throws -> Int {
        let descriptor = FetchDescriptor<SyncQueueEntity>()
        return try modelContext.fetchCount(descriptor)
    }

    func clearFailedItems() throws {
        let descriptor = FetchDescriptor<SyncQueueEntity>(
            predicate: #Predicate { $0.retryCount >= 3 }
        )
        let failedItems = try modelContext.fetch(descriptor)
        for item in failedItems {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func incrementRetry(id: Int64, error: String) throws {
        let descriptor = FetchDescriptor<SyncQueueEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let item = try modelContext.fetch(descriptor).first {
            item.retryCount += 1
            item.lastError = error
            try modelContext.save()
        }
    }
}

#endif
