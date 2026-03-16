import XCTest

final class ProfileManagementUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "Authenticated"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testNavigateToProfile() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let profileTitle = app.navigationBars["Profile"]
        XCTAssertTrue(profileTitle.waitForExistence(timeout: 5))
    }

    func testDisplayUserInfo() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let emailLabel = app.staticTexts["userEmail"]
        let displayNameLabel = app.staticTexts["userDisplayName"]

        XCTAssertTrue(emailLabel.waitForExistence(timeout: 2))
        XCTAssertTrue(displayNameLabel.exists)
    }

    func testEditProfileButton() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let editButton = app.buttons["Edit Profile"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2))

        editButton.tap()

        let editProfileSheet = app.sheets["Edit Profile"]
        XCTAssertTrue(editProfileSheet.waitForExistence(timeout: 2))
    }

    func testEditDisplayName() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let editButton = app.buttons["Edit Profile"]
        editButton.tap()

        let nameField = app.textFields["displayNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))

        nameField.tap()
        nameField.typeText("New Name")

        let saveButton = app.buttons["Save"]
        saveButton.tap()

        let updatedName = app.staticTexts["New Name"]
        XCTAssertTrue(updatedName.waitForExistence(timeout: 2))
    }

    func testWalkStatistics() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let totalWalksLabel = app.staticTexts["totalWalks"]
        let totalDistanceLabel = app.staticTexts["totalDistance"]
        let totalDurationLabel = app.staticTexts["totalDuration"]

        XCTAssertTrue(totalWalksLabel.waitForExistence(timeout: 2))
        XCTAssertTrue(totalDistanceLabel.exists)
        XCTAssertTrue(totalDurationLabel.exists)
    }

    func testDogProfileSection() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let dogProfileSection = app.buttons["Dog Profiles"]
        XCTAssertTrue(dogProfileSection.waitForExistence(timeout: 2))

        dogProfileSection.tap()

        let dogListView = app.navigationBars["Dog Profiles"]
        XCTAssertTrue(dogListView.waitForExistence(timeout: 2))
    }

    func testAddDogProfile() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let dogProfileSection = app.buttons["Dog Profiles"]
        dogProfileSection.tap()

        let addButton = app.buttons["Add Dog"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))

        addButton.tap()

        let nameField = app.textFields["dogNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
    }

    func testSignOutButton() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 2))

        signOutButton.tap()

        let confirmButton = app.alerts.buttons["Sign Out"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 2))

        confirmButton.tap()

        let loginScreen = app.navigationBars["Login"]
        XCTAssertTrue(loginScreen.waitForExistence(timeout: 3))
    }

    func testViewWalkHistory() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let walkHistoryButton = app.buttons["Walk History"]
        XCTAssertTrue(walkHistoryButton.waitForExistence(timeout: 2))

        walkHistoryButton.tap()

        let historyTitle = app.navigationBars["Walk History"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 2))
    }
}
