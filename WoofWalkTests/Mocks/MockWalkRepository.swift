import Foundation
import SwiftData
@testable import WoofWalk

@MainActor
class MockWalkRepository {
    var walks: [WalkEntity] = []
    var shouldThrowError = false

    var insertCalled = false
    var updateCalled = false
    var deleteCalled = false
    var markAsSyncedCalled = false

    func insert(_ walk: WalkEntity) throws {
        insertCalled = true
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        walks.append(walk)
    }

    func insertAll(_ walks: [WalkEntity]) throws {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        self.walks.append(contentsOf: walks)
    }

    func update(_ walk: WalkEntity) throws {
        updateCalled = true
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
    }

    func getWalkById(_ walkId: String) throws -> WalkEntity? {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        return walks.first { $0.id == walkId }
    }

    func getUserWalks(_ userId: String) throws -> [WalkEntity] {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        return walks.filter { $0.userId == userId }
    }

    func getRecentWalks(_ userId: String, limit: Int) throws -> [WalkEntity] {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        return Array(walks.filter { $0.userId == userId }.prefix(limit))
    }

    func getUnsyncedWalks() throws -> [WalkEntity] {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        return walks.filter { !$0.syncedToFirestore }
    }

    func markAsSynced(_ walkId: String) throws {
        markAsSyncedCalled = true
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        if let index = walks.firstIndex(where: { $0.id == walkId }) {
            walks[index].syncedToFirestore = true
        }
    }

    func getTotalDistance(_ userId: String) throws -> Int {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        return walks.filter { $0.userId == userId }.reduce(0) { $0 + $1.distanceMeters }
    }

    func getTotalDuration(_ userId: String) throws -> Int {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        return walks.filter { $0.userId == userId }.reduce(0) { $0 + $1.durationSec }
    }

    func getWalkCount(_ userId: String) throws -> Int {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        return walks.filter { $0.userId == userId }.count
    }

    func deleteById(_ walkId: String) throws {
        deleteCalled = true
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        walks.removeAll { $0.id == walkId }
    }

    func deleteAll() throws {
        guard !shouldThrowError else {
            throw NSError(domain: "MockWalkRepository", code: -1)
        }
        walks.removeAll()
    }
}
