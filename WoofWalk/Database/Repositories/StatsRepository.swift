import SwiftData
import Foundation

struct WeeklyRow {
    let dogId: String
    let yearWeek: String
    let totalDistanceMeters: Double
    let totalDurationSec: Int64
    let walkCount: Int
}

struct MonthlyRow {
    let dogId: String
    let yearMonth: String
    let totalDistanceMeters: Double
    let totalDurationSec: Int64
    let walkCount: Int
}

struct DailyWalkCount {
    let dayOfWeek: Int
    let walkCount: Int
}

@MainActor
class StatsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func weeklyStats(dogId: String, limitRows: Int = 12) throws -> [WeeklyRow] {
        let joins = try getJoinsForDog(dogId)
        let sessionIds = joins.map { $0.sessionId }

        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil && sessionIds.contains(session.sessionId)
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let sessions = try modelContext.fetch(descriptor)

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session -> String in
            let year = calendar.component(.yearForWeekOfYear, from: session.startedAt)
            let week = calendar.component(.weekOfYear, from: session.startedAt)
            return String(format: "%04d-W%02d", year, week)
        }

        return grouped.map { yearWeek, sessions in
            WeeklyRow(
                dogId: dogId,
                yearWeek: yearWeek,
                totalDistanceMeters: sessions.reduce(0) { $0 + $1.distanceMeters },
                totalDurationSec: sessions.reduce(0) { $0 + $1.durationSec },
                walkCount: sessions.count
            )
        }.sorted { $0.yearWeek > $1.yearWeek }.prefix(limitRows).map { $0 }
    }

    func monthlyStats(dogId: String, limitRows: Int = 12) throws -> [MonthlyRow] {
        let joins = try getJoinsForDog(dogId)
        let sessionIds = joins.map { $0.sessionId }

        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil && sessionIds.contains(session.sessionId)
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let sessions = try modelContext.fetch(descriptor)

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session -> String in
            let year = calendar.component(.year, from: session.startedAt)
            let month = calendar.component(.month, from: session.startedAt)
            return String(format: "%04d-%02d", year, month)
        }

        return grouped.map { yearMonth, sessions in
            MonthlyRow(
                dogId: dogId,
                yearMonth: yearMonth,
                totalDistanceMeters: sessions.reduce(0) { $0 + $1.distanceMeters },
                totalDurationSec: sessions.reduce(0) { $0 + $1.durationSec },
                walkCount: sessions.count
            )
        }.sorted { $0.yearMonth > $1.yearMonth }.prefix(limitRows).map { $0 }
    }

    func totalWalksForDog(_ dogId: String) throws -> Int {
        let joins = try getJoinsForDog(dogId)
        let sessionIds = joins.map { $0.sessionId }

        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil && sessionIds.contains(session.sessionId)
            }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func totalDistanceForDog(_ dogId: String) throws -> Double {
        let joins = try getJoinsForDog(dogId)
        let sessionIds = joins.map { $0.sessionId }

        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil && sessionIds.contains(session.sessionId)
            }
        )
        let sessions = try modelContext.fetch(descriptor)
        return sessions.reduce(0.0) { $0 + $1.distanceMeters }
    }

    func totalDurationForDog(_ dogId: String) throws -> Int64 {
        let joins = try getJoinsForDog(dogId)
        let sessionIds = joins.map { $0.sessionId }

        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil && sessionIds.contains(session.sessionId)
            }
        )
        let sessions = try modelContext.fetch(descriptor)
        return sessions.reduce(0) { $0 + $1.durationSec }
    }

    func getAllCompletedSessions() throws -> [WalkSessionEntity] {
        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getTotalWalkCount() throws -> Int {
        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { $0.endedAt != nil }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func getTotalDistance() throws -> Double {
        let sessions = try getAllCompletedSessions()
        return sessions.reduce(0.0) { $0 + $1.distanceMeters }
    }

    func getTotalDuration() throws -> Int64 {
        let sessions = try getAllCompletedSessions()
        return sessions.reduce(0) { $0 + $1.durationSec }
    }

    func getWeeklyWalkCounts() throws -> [DailyWalkCount] {
        let calendar = Calendar.current
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: Date())!

        let descriptor = FetchDescriptor<WalkSessionEntity>(
            predicate: #Predicate { session in
                session.endedAt != nil && session.startedAt >= sixDaysAgo
            }
        )
        let sessions = try modelContext.fetch(descriptor)

        let grouped = Dictionary(grouping: sessions) { session -> Int in
            calendar.component(.weekday, from: session.startedAt)
        }

        return grouped.map { dayOfWeek, sessions in
            DailyWalkCount(dayOfWeek: dayOfWeek, walkCount: sessions.count)
        }.sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    private func getJoinsForDog(_ dogId: String) throws -> [DogWalkJoin] {
        let descriptor = FetchDescriptor<DogWalkJoin>(
            predicate: #Predicate { $0.dogId == dogId }
        )
        return try modelContext.fetch(descriptor)
    }
}
