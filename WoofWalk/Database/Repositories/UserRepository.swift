import SwiftData
import Foundation

@MainActor
class UserRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func insert(_ user: UserEntity) throws {
        modelContext.insert(user)
        try modelContext.save()
    }

    func update(_ user: UserEntity) throws {
        try modelContext.save()
    }

    func getUserById(_ userId: String) throws -> UserEntity? {
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate { $0.id == userId }
        )
        return try modelContext.fetch(descriptor).first
    }

    func getUserByEmail(_ email: String) throws -> UserEntity? {
        let descriptor = FetchDescriptor<UserEntity>(
            predicate: #Predicate { $0.email == email }
        )
        return try modelContext.fetch(descriptor).first
    }

    func addPawPoints(userId: String, points: Int) throws {
        if let user = try getUserById(userId) {
            user.pawPoints += points
            try modelContext.save()
        }
    }

    func updateLevel(userId: String, level: Int) throws {
        if let user = try getUserById(userId) {
            user.level = level
            try modelContext.save()
        }
    }

    func updateLastSyncedAt(userId: String, timestamp: Date) throws {
        if let user = try getUserById(userId) {
            user.lastSyncedAt = timestamp
            try modelContext.save()
        }
    }

    func getLastSyncedAt(_ userId: String) throws -> Date? {
        return try getUserById(userId)?.lastSyncedAt
    }

    func deleteById(_ userId: String) throws {
        if let user = try getUserById(userId) {
            modelContext.delete(user)
            try modelContext.save()
        }
    }

    func deleteAll() throws {
        try modelContext.delete(model: UserEntity.self)
        try modelContext.save()
    }

    func getCount() throws -> Int {
        let descriptor = FetchDescriptor<UserEntity>()
        return try modelContext.fetchCount(descriptor)
    }
}
