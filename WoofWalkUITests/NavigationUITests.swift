import XCTest

final class NavigationUITests: XCTestCase {
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

    func testBottomNavigationTabs() throws {
        let mapTab = app.tabBars.buttons["Map"]
        let feedTab = app.tabBars.buttons["Feed"]
        let profileTab = app.tabBars.buttons["Profile"]

        XCTAssertTrue(mapTab.exists)
        XCTAssertTrue(feedTab.exists)
        XCTAssertTrue(profileTab.exists)
    }

    func testNavigateToFeed() throws {
        let feedTab = app.tabBars.buttons["Feed"]
        feedTab.tap()

        let feedTitle = app.navigationBars["Feed"]
        XCTAssertTrue(feedTitle.waitForExistence(timeout: 2))
    }

    func testNavigateToProfile() throws {
        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        let profileTitle = app.navigationBars["Profile"]
        XCTAssertTrue(profileTitle.waitForExistence(timeout: 2))
    }

    func testNavigateBackToMap() throws {
        let feedTab = app.tabBars.buttons["Feed"]
        feedTab.tap()

        let mapTab = app.tabBars.buttons["Map"]
        mapTab.tap()

        let mapTitle = app.navigationBars["Map"]
        XCTAssertTrue(mapTitle.waitForExistence(timeout: 2))
    }

    func testTabBarPersistence() throws {
        let feedTab = app.tabBars.buttons["Feed"]
        feedTab.tap()

        let profileTab = app.tabBars.buttons["Profile"]
        profileTab.tap()

        XCTAssertTrue(app.tabBars.buttons.count >= 3)
    }

    func testOnboardingFlow() throws {
        app.launchArguments = ["UI-Testing", "Reset-Onboarding"]
        app.launch()

        let welcomeText = app.staticTexts["Welcome to WoofWalk"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5))

        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.exists)

        getStartedButton.tap()

        let loginScreen = app.navigationBars["Login"]
        XCTAssertTrue(loginScreen.waitForExistence(timeout: 2))
    }

    func testLoginToSignup() throws {
        app.launchArguments = ["UI-Testing", "Show-Login"]
        app.launch()

        let signUpButton = app.buttons["Sign Up"]
        XCTAssertTrue(signUpButton.waitForExistence(timeout: 5))

        signUpButton.tap()

        let createAccountTitle = app.navigationBars["Create Account"]
        XCTAssertTrue(createAccountTitle.waitForExistence(timeout: 2))
    }

    func testForgotPasswordFlow() throws {
        app.launchArguments = ["UI-Testing", "Show-Login"]
        app.launch()

        let forgotPasswordButton = app.buttons["Forgot password?"]
        XCTAssertTrue(forgotPasswordButton.waitForExistence(timeout: 5))

        forgotPasswordButton.tap()

        let resetPasswordTitle = app.navigationBars["Reset Password"]
        XCTAssertTrue(resetPasswordTitle.waitForExistence(timeout: 2))
    }
}
