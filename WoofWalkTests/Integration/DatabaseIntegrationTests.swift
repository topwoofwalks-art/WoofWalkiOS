import XCTest
import SwiftData
@testable import WoofWalk

@MainActor
final class DatabaseIntegrationTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var walkRepository: WalkRepository!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([
            WalkEntity.self,
            POIEntity.self,
            DogProfile.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )

        modelContext = ModelContext(modelContainer)
        walkRepository = WalkRepository(modelContext: modelContext)
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        walkRepository = nil
        try await super.tearDown()
    }

    func testInsertAndFetchWalk() throws {
        let walk = TestDataBuilder.createTestWalk(id: "integration-walk-1")

        try walkRepository.insert(walk)

        let fetchedWalk = try walkRepository.getWalkById("integration-walk-1")
        XCTAssertNotNil(fetchedWalk)
        XCTAssertEqual(fetchedWalk?.id, "integration-walk-1")
    }

    func testUpdateWalk() throws {
        let walk = TestDataBuilder.createTestWalk(id: "update-walk")
        try walkRepository.insert(walk)

        if let fetchedWalk = try walkRepository.getWalkById("update-walk") {
            fetchedWalk.distanceMeters = 10000
            try walkRepository.update(fetchedWalk)
        }

        let updatedWalk = try walkRepository.getWalkById("update-walk")
        XCTAssertEqual(updatedWalk?.distanceMeters, 10000)
    }

    func testDeleteWalk() throws {
        let walk = TestDataBuilder.createTestWalk(id: "delete-walk")
        try walkRepository.insert(walk)

        try walkRepository.deleteById("delete-walk")

        let deletedWalk = try walkRepository.getWalkById("delete-walk")
        XCTAssertNil(deletedWalk)
    }

    func testCascadingOperations() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1", userId: "user-1"),
            TestDataBuilder.createTestWalk(id: "walk-2", userId: "user-1"),
            TestDataBuilder.createTestWalk(id: "walk-3", userId: "user-2")
        ]

        try walkRepository.insertAll(walks)

        try walkRepository.deleteUserWalks("user-1")

        let remainingWalks = try walkRepository.getUserWalks("user-1")
        XCTAssertEqual(remainingWalks.count, 0)

        let otherUserWalks = try walkRepository.getUserWalks("user-2")
        XCTAssertEqual(otherUserWalks.count, 1)
    }

    func testTransactionRollback() throws {
        let walk1 = TestDataBuilder.createTestWalk(id: "tx-walk-1")

        try walkRepository.insert(walk1)

        do {
            let invalidWalk = TestDataBuilder.createTestWalk(id: "tx-walk-1")
            try walkRepository.insert(invalidWalk)
            XCTFail("Should have thrown duplicate key error")
        } catch {
            let walks = try walkRepository.getUserWalks("test-user-123")
            XCTAssertEqual(walks.count, 1)
        }
    }

    func testComplexQuery() throws {
        let now = Date()
        let walks = [
            TestDataBuilder.createTestWalk(id: "recent-1", userId: "user-1"),
            TestDataBuilder.createTestWalk(id: "recent-2", userId: "user-1"),
            TestDataBuilder.createTestWalk(id: "old-1", userId: "user-1")
        ]

        try walkRepository.insertAll(walks)

        let recentWalks = try walkRepository.getRecentWalks("user-1", limit: 2)
        XCTAssertEqual(recentWalks.count, 2)
    }

    func testAggregateOperations() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "agg-1", userId: "user-1", distanceMeters: 5000, durationSec: 3600),
            TestDataBuilder.createTestWalk(id: "agg-2", userId: "user-1", distanceMeters: 3000, durationSec: 1800)
        ]

        try walkRepository.insertAll(walks)

        let totalDistance = try walkRepository.getTotalDistance("user-1")
        let totalDuration = try walkRepository.getTotalDuration("user-1")
        let walkCount = try walkRepository.getWalkCount("user-1")

        XCTAssertEqual(totalDistance, 8000)
        XCTAssertEqual(totalDuration, 5400)
        XCTAssertEqual(walkCount, 2)
    }
}
