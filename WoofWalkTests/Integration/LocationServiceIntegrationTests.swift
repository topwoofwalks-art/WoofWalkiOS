import XCTest
import CoreLocation
import Combine
@testable import WoofWalk

@MainActor
final class LocationServiceIntegrationTests: XCTestCase {
    var locationService: MockLocationService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        locationService = MockLocationService()
        cancellables = []
    }

    override func tearDown() {
        locationService = nil
        cancellables = nil
        super.tearDown()
    }

    func testLocationUpdates() {
        let expectation = XCTestExpectation(description: "Location updates received")
        var receivedLocations: [CLLocation] = []

        locationService.currentLocationPublisher
            .compactMap { $0 }
            .sink { location in
                receivedLocations.append(location)
                if receivedLocations.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        locationService.startTracking()

        let locations = [
            TestDataBuilder.createTestLocation(latitude: 51.5074, longitude: -0.1278),
            TestDataBuilder.createTestLocation(latitude: 51.5075, longitude: -0.1279),
            TestDataBuilder.createTestLocation(latitude: 51.5076, longitude: -0.1280)
        ]

        for location in locations {
            locationService.simulateLocation(location)
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedLocations.count, 3)
    }

    func testAuthorizationFlow() {
        let expectation = XCTestExpectation(description: "Authorization status changes")
        var receivedStatuses: [CLAuthorizationStatus] = []

        locationService.authorizationStatusPublisher
            .sink { status in
                receivedStatuses.append(status)
                if receivedStatuses.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        locationService.requestAuthorization()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(locationService.requestAuthorizationCalled)
        XCTAssertEqual(receivedStatuses.last, .authorizedWhenInUse)
    }

    func testTrackingLifecycle() {
        locationService.startTracking()
        XCTAssertTrue(locationService.startTrackingCalled)
        XCTAssertTrue(locationService.isTracking)

        locationService.stopTracking()
        XCTAssertTrue(locationService.stopTrackingCalled)
        XCTAssertFalse(locationService.isTracking)
    }

    func testDistanceCalculation() {
        let start = TestDataBuilder.createTestLocation(latitude: 51.5074, longitude: -0.1278)
        let end = TestDataBuilder.createTestLocation(latitude: 51.5084, longitude: -0.1278)

        let distance = start.distance(from: end)

        XCTAssertGreaterThan(distance, 100)
        XCTAssertLessThan(distance, 200)
    }

    func testAccuracyFiltering() {
        let goodLocation = TestDataBuilder.createTestLocation(accuracy: 10.0)
        let badLocation = TestDataBuilder.createTestLocation(accuracy: 100.0)

        XCTAssertLessThan(goodLocation.horizontalAccuracy, 50)
        XCTAssertGreaterThan(badLocation.horizontalAccuracy, 50)
    }
}
