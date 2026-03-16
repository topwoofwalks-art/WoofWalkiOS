import XCTest
import MapKit
import Combine
@testable import WoofWalk

@MainActor
final class MapViewModelTests: XCTestCase {
    var viewModel: MapViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        viewModel = MapViewModel()
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        cancellables = nil
        super.tearDown()
    }

    func testTogglePOIType() {
        let initialCount = viewModel.selectedPOITypes.count

        viewModel.togglePOIType(.bin)

        XCTAssertEqual(viewModel.selectedPOITypes.count, initialCount - 1)
        XCTAssertFalse(viewModel.selectedPOITypes.contains(.bin))

        viewModel.togglePOIType(.bin)

        XCTAssertEqual(viewModel.selectedPOITypes.count, initialCount)
        XCTAssertTrue(viewModel.selectedPOITypes.contains(.bin))
    }

    func testClearFilters() {
        viewModel.togglePOIType(.bin)
        viewModel.togglePOIType(.water)

        XCTAssertLessThan(viewModel.selectedPOITypes.count, POI.POIType.allCases.count)

        viewModel.clearFilters()

        XCTAssertEqual(viewModel.selectedPOITypes.count, POI.POIType.allCases.count)
    }

    func testFilteredPOIsUpdatesWhenTypesChange() {
        let binPoi = TestDataBuilder.createTestPOI(id: "bin-1", type: .bin)
        let waterPoi = TestDataBuilder.createTestPOI(id: "water-1", type: .water)

        viewModel.pois = [binPoi, waterPoi]

        let expectation = XCTestExpectation(description: "Filtered POIs updates")

        viewModel.$filteredPOIs
            .dropFirst()
            .sink { filtered in
                XCTAssertEqual(filtered.count, 1)
                XCTAssertEqual(filtered.first?.type, .water)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        viewModel.togglePOIType(.bin)

        wait(for: [expectation], timeout: 1.0)
    }

    func testAddPOI() {
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let initialCount = viewModel.pois.count

        viewModel.addPOI(type: .bin, at: coordinate)

        XCTAssertEqual(viewModel.pois.count, initialCount + 1)
        XCTAssertEqual(viewModel.pois.last?.type, .bin)
    }

    func testRemovePOI() {
        let poi = TestDataBuilder.createTestPOI(id: "remove-me")
        viewModel.pois = [poi]

        viewModel.removePOI(poi)

        XCTAssertEqual(viewModel.pois.count, 0)
    }

    func testStartWalkTracking() {
        viewModel.startWalkTracking()

        XCTAssertNotNil(viewModel.walkStartTime)
        XCTAssertEqual(viewModel.walkDistance, 0)
        XCTAssertEqual(viewModel.walkPolyline.count, 0)
    }

    func testStopWalkTracking() {
        viewModel.startWalkTracking()

        viewModel.stopWalkTracking()

        XCTAssertNil(viewModel.walkStartTime)
        XCTAssertNil(viewModel.walkTimer)
    }

    func testUpdateWalkPolyline() {
        let coord1 = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let coord2 = CLLocationCoordinate2D(latitude: 51.5084, longitude: -0.1278)

        viewModel.updateWalkPolyline(with: coord1)
        XCTAssertEqual(viewModel.walkPolyline.count, 1)
        XCTAssertEqual(viewModel.walkDistance, 0)

        viewModel.updateWalkPolyline(with: coord2)
        XCTAssertEqual(viewModel.walkPolyline.count, 2)
        XCTAssertGreaterThan(viewModel.walkDistance, 0)
    }

    func testWalkDistanceCalculation() {
        let start = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let end = CLLocationCoordinate2D(latitude: 51.5084, longitude: -0.1278)

        viewModel.updateWalkPolyline(with: start)
        viewModel.updateWalkPolyline(with: end)

        let expectedDistance = CLLocation(latitude: 51.5074, longitude: -0.1278)
            .distance(from: CLLocation(latitude: 51.5084, longitude: -0.1278))

        XCTAssertEqual(viewModel.walkDistance, expectedDistance, accuracy: 1.0)
    }

    func testCycleCameraMode() {
        XCTAssertEqual(viewModel.cameraMode, .free)

        viewModel.cycleCameraMode()
        XCTAssertEqual(viewModel.cameraMode, .follow)

        viewModel.cycleCameraMode()
        XCTAssertEqual(viewModel.cameraMode, .overview)

        viewModel.cycleCameraMode()
        XCTAssertEqual(viewModel.cameraMode, .tilt)

        viewModel.cycleCameraMode()
        XCTAssertEqual(viewModel.cameraMode, .follow)
    }

    func testSearchLocationEmptyQuery() {
        viewModel.searchLocation("")

        XCTAssertEqual(viewModel.searchResults.count, 0)
    }

    func testAddPooBagDrop() {
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let initialCount = viewModel.activeBagDrops.count

        viewModel.addPooBagDrop(at: coordinate)

        XCTAssertEqual(viewModel.activeBagDrops.count, initialCount + 1)
        XCTAssertCoordinateEqual(
            viewModel.activeBagDrops.last!.coordinate,
            coordinate
        )
    }

    func testCameraModeIcon() {
        viewModel.cameraMode = .free
        XCTAssertEqual(viewModel.cameraModeIcon, "hand.point.up.left.fill")

        viewModel.cameraMode = .follow
        XCTAssertEqual(viewModel.cameraModeIcon, "location.fill")

        viewModel.cameraMode = .overview
        XCTAssertEqual(viewModel.cameraModeIcon, "map.fill")

        viewModel.cameraMode = .tilt
        XCTAssertEqual(viewModel.cameraModeIcon, "camera.fill")
    }
}
