import XCTest
import CoreLocation
@testable import WoofWalk

@MainActor
final class PoiRepositoryTests: XCTestCase {
    var repository: MockPoiRepository!

    override func setUp() {
        super.setUp()
        repository = MockPoiRepository()
    }

    override func tearDown() {
        repository = nil
        super.tearDown()
    }

    func testGetPoisNearby() async throws {
        let testPoi = TestDataBuilder.createTestPOI()
        repository.pois = [testPoi]

        let center = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let pois = try await repository.getPoisNearby(center: center, radiusMeters: 1000)

        XCTAssertEqual(pois.count, 1)
        XCTAssertEqual(pois.first?.id, testPoi.id)
    }

    func testAddPoi() async throws {
        let poi = TestDataBuilder.createTestPOI(id: "new-poi")

        try await repository.addPoi(poi)

        XCTAssertTrue(repository.addPoiCalled)
        XCTAssertEqual(repository.pois.count, 1)
        XCTAssertEqual(repository.pois.first?.id, "new-poi")
    }

    func testDeletePoi() async throws {
        let poi = TestDataBuilder.createTestPOI(id: "poi-to-delete")
        try await repository.addPoi(poi)

        try await repository.deletePoi("poi-to-delete")

        XCTAssertTrue(repository.deletePoiCalled)
        XCTAssertEqual(repository.pois.count, 0)
    }

    func testVotePoiUpvote() async throws {
        let poi = TestDataBuilder.createTestPOI(id: "poi-123")
        try await repository.addPoi(poi)

        try await repository.votePoi("poi-123", isUpvote: true)

        XCTAssertTrue(repository.votePoiCalled)
        XCTAssertEqual(repository.pois.first?.voteUp, 1)
        XCTAssertEqual(repository.pois.first?.voteDown, 0)
    }

    func testVotePoiDownvote() async throws {
        let poi = TestDataBuilder.createTestPOI(id: "poi-123")
        try await repository.addPoi(poi)

        try await repository.votePoi("poi-123", isUpvote: false)

        XCTAssertTrue(repository.votePoiCalled)
        XCTAssertEqual(repository.pois.first?.voteUp, 0)
        XCTAssertEqual(repository.pois.first?.voteDown, 1)
    }

    func testGetPoisNearbyThrowsError() async {
        repository.shouldThrowError = true
        let center = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

        await XCTAssertThrowsErrorAsync(try await repository.getPoisNearby(center: center, radiusMeters: 1000))
    }

    func testAddPoiThrowsError() async {
        repository.shouldThrowError = true
        let poi = TestDataBuilder.createTestPOI()

        await XCTAssertThrowsErrorAsync(try await repository.addPoi(poi))
    }
}
