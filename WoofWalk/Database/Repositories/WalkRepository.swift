#if false
import SwiftData
import Foundation

@MainActor
class WalkRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func insert(_ walk: WalkEntity) throws {
        modelContext.insert(walk)
        try modelContext.save()
    }

    func insertAll(_ walks: [WalkEntity]) throws {
        for walk in walks {
            modelContext.insert(walk)
        }
        try modelContext.save()
    }

    func update(_ walk: WalkEntity) throws {
        try modelContext.save()
    }

    func getWalkById(_ walkId: String) throws -> WalkEntity? {
        let descriptor = FetchDescriptor<WalkEntity>(
            predicate: #Predicate { $0.id == walkId }
        )
        return try modelContext.fetch(descriptor).first
    }

    func getUserWalks(_ userId: String) throws -> [WalkEntity] {
        let descriptor = FetchDescriptor<WalkEntity>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getRecentWalks(_ userId: String, limit: Int) throws -> [WalkEntity] {
        var descriptor = FetchDescriptor<WalkEntity>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func getUnsyncedWalks() throws -> [WalkEntity] {
        let descriptor = FetchDescriptor<WalkEntity>(
            predicate: #Predicate { $0.syncedToFirestore == false }
        )
        return try modelContext.fetch(descriptor)
    }

    func markAsSynced(_ walkId: String) throws {
        if let walk = try getWalkById(walkId) {
            walk.syncedToFirestore = true
            try modelContext.save()
        }
    }

    func getTotalDistance(_ userId: String) throws -> Int {
        let walks = try getUserWalks(userId)
        return walks.reduce(0) { $0 + $1.distanceMeters }
    }

    func getTotalDuration(_ userId: String) throws -> Int {
        let walks = try getUserWalks(userId)
        return walks.reduce(0) { $0 + $1.durationSec }
    }

    func getWalkCount(_ userId: String) throws -> Int {
        let descriptor = FetchDescriptor<WalkEntity>(
            predicate: #Predicate { $0.userId == userId }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func getWalksInDateRange(userId: String, startTime: Date, endTime: Date) throws -> [WalkEntity] {
        let descriptor = FetchDescriptor<WalkEntity>(
            predicate: #Predicate { walk in
                walk.userId == userId &&
                walk.startedAt >= startTime &&
                walk.startedAt <= endTime
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func deleteById(_ walkId: String) throws {
        if let walk = try getWalkById(walkId) {
            modelContext.delete(walk)
            try modelContext.save()
        }
    }

    func deleteUserWalks(_ userId: String) throws {
        let walks = try getUserWalks(userId)
        for walk in walks {
            modelContext.delete(walk)
        }
        try modelContext.save()
    }

    func deleteAll() throws {
        try modelContext.delete(model: WalkEntity.self)
        try modelContext.save()
    }
}

#endif
