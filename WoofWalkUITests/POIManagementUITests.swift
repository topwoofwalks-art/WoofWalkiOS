import XCTest

final class POIManagementUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testPOIFilterButton() throws {
        let filterButton = app.buttons["POI Filters"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5))

        filterButton.tap()

        let binFilter = app.buttons["Bin"]
        let waterFilter = app.buttons["Water"]
        let parkFilter = app.buttons["Park"]

        XCTAssertTrue(binFilter.exists)
        XCTAssertTrue(waterFilter.exists)
        XCTAssertTrue(parkFilter.exists)
    }

    func testTogglePOIFilter() throws {
        let filterButton = app.buttons["POI Filters"]
        filterButton.tap()

        let binFilter = app.buttons["Bin"]
        let initialState = binFilter.isSelected

        binFilter.tap()

        XCTAssertNotEqual(binFilter.isSelected, initialState)
    }

    func testClearAllFilters() throws {
        let filterButton = app.buttons["POI Filters"]
        filterButton.tap()

        let binFilter = app.buttons["Bin"]
        binFilter.tap()

        let clearButton = app.buttons["Clear All"]
        XCTAssertTrue(clearButton.exists)

        clearButton.tap()

        XCTAssertTrue(binFilter.isSelected)
    }

    func testAddPOIButton() throws {
        let addPOIButton = app.buttons["Add POI"]
        XCTAssertTrue(addPOIButton.waitForExistence(timeout: 5))

        addPOIButton.tap()

        let poiTypeSheet = app.sheets["Select POI Type"]
        XCTAssertTrue(poiTypeSheet.waitForExistence(timeout: 2))
    }

    func testSelectPOIType() throws {
        let addPOIButton = app.buttons["Add POI"]
        addPOIButton.tap()

        let binButton = app.buttons["Bin"]
        XCTAssertTrue(binButton.waitForExistence(timeout: 2))

        binButton.tap()

        let mapView = app.otherElements["MapView"]
        XCTAssertTrue(mapView.exists)
    }

    func testPOIMarkerTap() throws {
        let mapView = app.otherElements["MapView"]
        XCTAssertTrue(mapView.waitForExistence(timeout: 5))

        let poiMarkers = app.otherElements.matching(identifier: "POIMarker")
        if poiMarkers.count > 0 {
            poiMarkers.element(boundBy: 0).tap()

            let poiDetailSheet = app.sheets["POI Details"]
            XCTAssertTrue(poiDetailSheet.waitForExistence(timeout: 2))
        }
    }

    func testVotePOI() throws {
        let mapView = app.otherElements["MapView"]
        mapView.tap()

        let poiMarkers = app.otherElements.matching(identifier: "POIMarker")
        if poiMarkers.count > 0 {
            poiMarkers.element(boundBy: 0).tap()

            let upvoteButton = app.buttons["Upvote"]
            if upvoteButton.exists {
                upvoteButton.tap()

                let voteCount = app.staticTexts["voteCount"]
                XCTAssertTrue(voteCount.exists)
            }
        }
    }
}
