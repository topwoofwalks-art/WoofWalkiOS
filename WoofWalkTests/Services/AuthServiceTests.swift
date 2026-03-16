import XCTest
import Combine
@testable import WoofWalk

@MainActor
final class AuthServiceTests: XCTestCase {
    var authService: MockAuthService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        authService = MockAuthService()
        cancellables = []
    }

    override func tearDown() {
        authService = nil
        cancellables = nil
        super.tearDown()
    }

    func testSignInSuccess() async throws {
        authService.shouldSucceed = true

        try await authService.signIn(email: "test@example.com", password: "password123")

        XCTAssertTrue(authService.signInCalled)
        XCTAssertNotNil(authService.currentUser)
        XCTAssertEqual(authService.currentUser?.email, "test@example.com")
        XCTAssertEqual(authService.authenticationState, .authenticated)
    }

    func testSignInFailure() async {
        authService.shouldSucceed = false

        do {
            try await authService.signIn(email: "test@example.com", password: "wrong")
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertTrue(authService.signInCalled)
            XCTAssertNil(authService.currentUser)
        }
    }

    func testSignUpSuccess() async throws {
        authService.shouldSucceed = true

        try await authService.signUp(
            email: "newuser@example.com",
            password: "password123",
            displayName: "New User"
        )

        XCTAssertTrue(authService.signUpCalled)
        XCTAssertNotNil(authService.currentUser)
        XCTAssertEqual(authService.currentUser?.displayName, "New User")
    }

    func testSignOut() throws {
        authService.currentUser = TestDataBuilder.createTestUser()
        authService.shouldSucceed = true

        try authService.signOut()

        XCTAssertTrue(authService.signOutCalled)
        XCTAssertNil(authService.currentUser)
        XCTAssertEqual(authService.authenticationState, .unauthenticated)
    }

    func testResetPassword() async throws {
        authService.shouldSucceed = true

        try await authService.resetPassword(email: "test@example.com")

        XCTAssertTrue(authService.resetPasswordCalled)
    }

    func testUpdateProfile() async throws {
        authService.currentUser = TestDataBuilder.createTestUser()
        authService.shouldSucceed = true

        try await authService.updateProfile(displayName: "Updated Name", photoURL: nil)

        XCTAssertEqual(authService.currentUser?.displayName, "Updated Name")
    }

    func testAuthenticationStatePublisher() {
        let expectation = XCTestExpectation(description: "Auth state updates")
        var states: [AuthenticationState] = []

        authService.authenticationStatePublisher
            .sink { state in
                states.append(state)
                if states.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        authService.authenticationState = .authenticated

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(states.last, .authenticated)
    }
}
