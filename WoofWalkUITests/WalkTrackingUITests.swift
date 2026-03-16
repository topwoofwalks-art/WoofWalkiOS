import XCTest

final class WalkTrackingUITests: XCTestCase {
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

    func testStartWalkButton() throws {
        let startButton = app.buttons["Start Walk"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))

        startButton.tap()

        let pauseButton = app.buttons["Pause"]
        let stopButton = app.buttons["Stop"]

        XCTAssertTrue(pauseButton.exists)
        XCTAssertTrue(stopButton.exists)
    }

    func testPauseWalkButton() throws {
        let startButton = app.buttons["Start Walk"]
        startButton.tap()

        let pauseButton = app.buttons["Pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))

        pauseButton.tap()

        let resumeButton = app.buttons["Resume"]
        XCTAssertTrue(resumeButton.exists)
    }

    func testResumeWalkButton() throws {
        let startButton = app.buttons["Start Walk"]
        startButton.tap()

        let pauseButton = app.buttons["Pause"]
        pauseButton.tap()

        let resumeButton = app.buttons["Resume"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 2))

        resumeButton.tap()

        let pauseButtonAgain = app.buttons["Pause"]
        XCTAssertTrue(pauseButtonAgain.exists)
    }

    func testStopWalkButton() throws {
        let startButton = app.buttons["Start Walk"]
        startButton.tap()

        let stopButton = app.buttons["Stop"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 2))

        stopButton.tap()

        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
    }

    func testWalkDistanceDisplay() throws {
        let startButton = app.buttons["Start Walk"]
        startButton.tap()

        let distanceLabel = app.staticTexts["walkDistance"]
        XCTAssertTrue(distanceLabel.waitForExistence(timeout: 2))
    }

    func testWalkDurationDisplay() throws {
        let startButton = app.buttons["Start Walk"]
        startButton.tap()

        let durationLabel = app.staticTexts["walkDuration"]
        XCTAssertTrue(durationLabel.waitForExistence(timeout: 2))
    }

    func testWalkTrackingFlow() throws {
        let startButton = app.buttons["Start Walk"]
        startButton.tap()

        sleep(2)

        let pauseButton = app.buttons["Pause"]
        pauseButton.tap()

        sleep(1)

        let resumeButton = app.buttons["Resume"]
        resumeButton.tap()

        sleep(1)

        let stopButton = app.buttons["Stop"]
        stopButton.tap()

        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
    }
}
