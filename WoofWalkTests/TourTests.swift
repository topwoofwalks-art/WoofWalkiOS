import XCTest
@testable import WoofWalk

final class TourTests: XCTestCase {

    func testTourStepProgression() {
        let steps = [
            TourStep(id: "1", title: "Step 1", message: "First", targetElement: nil, action: nil, order: 0, isCompleted: false),
            TourStep(id: "2", title: "Step 2", message: "Second", targetElement: nil, action: nil, order: 1, isCompleted: false),
            TourStep(id: "3", title: "Step 3", message: "Third", targetElement: nil, action: nil, order: 2, isCompleted: false)
        ]

        let tour = Tour(
            id: "test_tour",
            title: "Test Tour",
            description: "Test",
            steps: steps,
            targetScreen: .map,
            priority: 1,
            completedAt: nil
        )

        XCTAssertEqual(tour.steps.count, 3)
        XCTAssertFalse(tour.isCompleted)
        XCTAssertEqual(tour.progress, 0.0)
    }

    func testTourCompletion() {
        var tour = Tour(
            id: "test_tour",
            title: "Test Tour",
            description: "Test",
            steps: [],
            targetScreen: .map,
            priority: 1,
            completedAt: nil
        )

        XCTAssertFalse(tour.isCompleted)

        tour.completedAt = Date()
        XCTAssertTrue(tour.isCompleted)
    }

    func testTourProgress() {
        let steps = [
            TourStep(id: "1", title: "Step 1", message: "First", targetElement: nil, action: nil, order: 0, isCompleted: true),
            TourStep(id: "2", title: "Step 2", message: "Second", targetElement: nil, action: nil, order: 1, isCompleted: true),
            TourStep(id: "3", title: "Step 3", message: "Third", targetElement: nil, action: nil, order: 2, isCompleted: false)
        ]

        let tour = Tour(
            id: "test_tour",
            title: "Test Tour",
            description: "Test",
            steps: steps,
            targetScreen: .map,
            priority: 1,
            completedAt: nil
        )

        let expectedProgress = 2.0 / 3.0
        XCTAssertEqual(tour.progress, expectedProgress, accuracy: 0.01)
    }

    func testTourStepOrdering() {
        let steps = [
            TourStep(id: "1", title: "Step 1", message: "First", targetElement: nil, action: nil, order: 0, isCompleted: false),
            TourStep(id: "2", title: "Step 2", message: "Second", targetElement: nil, action: nil, order: 1, isCompleted: false),
            TourStep(id: "3", title: "Step 3", message: "Third", targetElement: nil, action: nil, order: 2, isCompleted: false)
        ]

        for i in 0..<steps.count {
            XCTAssertEqual(steps[i].order, i)
        }
    }

    func testTourActionIcons() {
        XCTAssertEqual(TourAction.tap.icon, "hand.tap")
        XCTAssertEqual(TourAction.swipe.icon, "hand.draw")
        XCTAssertEqual(TourAction.longPress.icon, "hand.point.up.left")
        XCTAssertEqual(TourAction.doubleTap.icon, "hand.tap.fill")
    }

    func testTourTargetDisplayNames() {
        XCTAssertEqual(TourTarget.map.displayName, "Map")
        XCTAssertEqual(TourTarget.walkTracking.displayName, "Walk Tracking")
        XCTAssertEqual(TourTarget.poi.displayName, "Points of Interest")
        XCTAssertEqual(TourTarget.livestockFields.displayName, "Livestock Fields")
        XCTAssertEqual(TourTarget.walkingPaths.displayName, "Walking Paths")
    }
}
