import XCTest
import SwiftData
@testable import WoofWalk

@MainActor
final class WalkRepositoryTests: XCTestCase {
    var repository: MockWalkRepository!
    var testUserId: String!

    override func setUp() {
        super.setUp()
        repository = MockWalkRepository()
        testUserId = "test-user-123"
    }

    override func tearDown() {
        repository = nil
        testUserId = nil
        super.tearDown()
    }

    func testInsertWalk() throws {
        let walk = TestDataBuilder.createTestWalk(userId: testUserId)

        try repository.insert(walk)

        XCTAssertTrue(repository.insertCalled)
        XCTAssertEqual(repository.walks.count, 1)
        XCTAssertEqual(repository.walks.first?.id, walk.id)
    }

    func testInsertMultipleWalks() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1", userId: testUserId),
            TestDataBuilder.createTestWalk(id: "walk-2", userId: testUserId)
        ]

        try repository.insertAll(walks)

        XCTAssertEqual(repository.walks.count, 2)
    }

    func testGetWalkById() throws {
        let walk = TestDataBuilder.createTestWalk(id: "walk-123", userId: testUserId)
        try repository.insert(walk)

        let fetchedWalk = try repository.getWalkById("walk-123")

        XCTAssertNotNil(fetchedWalk)
        XCTAssertEqual(fetchedWalk?.id, "walk-123")
    }

    func testGetWalkByIdNotFound() throws {
        let fetchedWalk = try repository.getWalkById("nonexistent")

        XCTAssertNil(fetchedWalk)
    }

    func testGetUserWalks() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1", userId: testUserId),
            TestDataBuilder.createTestWalk(id: "walk-2", userId: testUserId),
            TestDataBuilder.createTestWalk(id: "walk-3", userId: "other-user")
        ]
        try repository.insertAll(walks)

        let userWalks = try repository.getUserWalks(testUserId)

        XCTAssertEqual(userWalks.count, 2)
        XCTAssertTrue(userWalks.allSatisfy { $0.userId == testUserId })
    }

    func testGetRecentWalks() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1", userId: testUserId),
            TestDataBuilder.createTestWalk(id: "walk-2", userId: testUserId),
            TestDataBuilder.createTestWalk(id: "walk-3", userId: testUserId)
        ]
        try repository.insertAll(walks)

        let recentWalks = try repository.getRecentWalks(testUserId, limit: 2)

        XCTAssertEqual(recentWalks.count, 2)
    }

    func testGetUnsyncedWalks() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1", syncedToFirestore: false),
            TestDataBuilder.createTestWalk(id: "walk-2", syncedToFirestore: true),
            TestDataBuilder.createTestWalk(id: "walk-3", syncedToFirestore: false)
        ]
        try repository.insertAll(walks)

        let unsyncedWalks = try repository.getUnsyncedWalks()

        XCTAssertEqual(unsyncedWalks.count, 2)
        XCTAssertTrue(unsyncedWalks.allSatisfy { !$0.syncedToFirestore })
    }

    func testMarkAsSynced() throws {
        let walk = TestDataBuilder.createTestWalk(id: "walk-123", syncedToFirestore: false)
        try repository.insert(walk)

        try repository.markAsSynced("walk-123")

        XCTAssertTrue(repository.markAsSyncedCalled)
        let fetchedWalk = try repository.getWalkById("walk-123")
        XCTAssertTrue(fetchedWalk?.syncedToFirestore ?? false)
    }

    func testGetTotalDistance() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1", userId: testUserId, distanceMeters: 5000),
            TestDataBuilder.createTestWalk(id: "walk-2", userId: testUserId, distanceMeters: 3000),
            TestDataBuilder.createTestWalk(id: "walk-3", userId: "other-user", distanceMeters: 2000)
        ]
        try repository.insertAll(walks)

        let totalDistance = try repository.getTotalDistance(testUserId)

        XCTAssertEqual(totalDistance, 8000)
    }

    func testGetTotalDuration() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1", userId: testUserId, durationSec: 3600),
            TestDataBuilder.createTestWalk(id: "walk-2", userId: testUserId, durationSec: 1800)
        ]
        try repository.insertAll(walks)

        let totalDuration = try repository.getTotalDuration(testUserId)

        XCTAssertEqual(totalDuration, 5400)
    }

    func testGetWalkCount() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1", userId: testUserId),
            TestDataBuilder.createTestWalk(id: "walk-2", userId: testUserId),
            TestDataBuilder.createTestWalk(id: "walk-3", userId: "other-user")
        ]
        try repository.insertAll(walks)

        let count = try repository.getWalkCount(testUserId)

        XCTAssertEqual(count, 2)
    }

    func testDeleteById() throws {
        let walk = TestDataBuilder.createTestWalk(id: "walk-123")
        try repository.insert(walk)

        try repository.deleteById("walk-123")

        XCTAssertTrue(repository.deleteCalled)
        XCTAssertEqual(repository.walks.count, 0)
    }

    func testDeleteAll() throws {
        let walks = [
            TestDataBuilder.createTestWalk(id: "walk-1"),
            TestDataBuilder.createTestWalk(id: "walk-2")
        ]
        try repository.insertAll(walks)

        try repository.deleteAll()

        XCTAssertEqual(repository.walks.count, 0)
    }

    func testInsertThrowsError() {
        repository.shouldThrowError = true
        let walk = TestDataBuilder.createTestWalk()

        XCTAssertThrowsError(try repository.insert(walk))
    }

    func testGetWalkByIdThrowsError() {
        repository.shouldThrowError = true

        XCTAssertThrowsError(try repository.getWalkById("walk-123"))
    }
}
