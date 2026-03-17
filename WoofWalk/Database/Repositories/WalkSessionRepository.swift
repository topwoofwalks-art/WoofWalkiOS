#if false
import SwiftData
import Foundation

@MainActor
class WalkSessionRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func insertSession(_ session: WalkSessionEntity) throws {
        modelContext.insert(session)
        try modelContext.save()
    }

    func updateSession(_ session: WalkSessionEntity) throws {
        try modelContext.save()
    }

    func insertJoin(_ join: DogWalkJoin) throws {
        modelContext.insert(join)
        try modelContext.save()
    }

    func insertJoins(_ joins: [DogWalkJoin]) throws {
        for join in joins {
            modelContext.insert(join)
        }
        try modelContext.save()
    }

    func insertPoints(_ points: [TrackPointEntity]) throws {
        for point in points {
            modelContext.insert(point)
        }
        try modelContext.save()
    }

    func insertPoint(_ point: TrackPointEntity) throws {
        modelContext.insert(point)
        try modelContext.save()
    }

    func getSession(_ id: String) throws -> WalkSessionEntity? {
        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { $0.sessionId == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func getActiveSession() throws -> WalkSessionEntity? {
        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        var fetchDescriptor = descriptor
        fetchDescriptor.fetchLimit = 1
        return try modelContext.fetch(fetchDescriptor).first
    }

    func sessionsForDog(_ dogId: String) throws -> [WalkSessionEntity] {
        let joins = try getJoinsForDog(dogId)
        let sessionIds = joins.map { $0.sessionId }

        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil && sessionIds.contains(session.sessionId)
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func recentSessionsForDog(_ dogId: String, limit: Int) throws -> [WalkSessionEntity] {
        let joins = try getJoinsForDog(dogId)
        let sessionIds = joins.map { $0.sessionId }

        var descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil && sessionIds.contains(session.sessionId)
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func getTrackPoints(_ sessionId: String) throws -> [TrackPointEntity] {
        let descriptor = FetchDescriptor<TrackPointEntity>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getDogsForSession(_ sessionId: String) throws -> [String] {
        let descriptor = FetchDescriptor<DogWalkJoin>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        return try modelContext.fetch(descriptor).map { $0.dogId }
    }

    private func getJoinsForDog(_ dogId: String) throws -> [DogWalkJoin] {
        let descriptor = FetchDescriptor<DogWalkJoin>(
            predicate: #Predicate { $0.dogId == dogId }
        )
        return try modelContext.fetch(descriptor)
    }

    func deleteTrackPoints(_ sessionId: String) throws {
        let points = try getTrackPoints(sessionId)
        for point in points {
            modelContext.delete(point)
        }
        try modelContext.save()
    }

    func deleteDogWalkJoins(_ sessionId: String) throws {
        let descriptor = FetchDescriptor<DogWalkJoin>(
            predicate: #Predicate { $0.sessionId == sessionId }
        )
        let joins = try modelContext.fetch(descriptor)
        for join in joins {
            modelContext.delete(join)
        }
        try modelContext.save()
    }

    func deleteSession(_ sessionId: String) throws {
        if let session = try getSession(sessionId) {
            modelContext.delete(session)
            try modelContext.save()
        }
    }

    func getWalksCompletedOnDate(startOfDay: Date, endOfDay: Date) throws -> Int {
        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil &&
                session.endedAt! >= startOfDay &&
                session.endedAt! < endOfDay
            }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func hasWalksOnDate(startOfDay: Date, endOfDay: Date) throws -> Bool {
        return try getWalksCompletedOnDate(startOfDay: startOfDay, endOfDay: endOfDay) > 0
    }
}

#endif
