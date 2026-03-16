import XCTest
import Combine
@testable import WoofWalk

@MainActor
final class AuthViewModelTests: XCTestCase {
    var viewModel: AuthViewModel!
    var mockAuthService: MockAuthService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockAuthService = MockAuthService()
        viewModel = AuthViewModel(authService: mockAuthService)
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        mockAuthService = nil
        cancellables = nil
        super.tearDown()
    }

    func testSignInSuccess() async throws {
        mockAuthService.shouldSucceed = true

        try await viewModel.signIn(email: "test@example.com", password: "password123")

        XCTAssertTrue(mockAuthService.signInCalled)
        XCTAssertNotNil(mockAuthService.currentUser)
        XCTAssertEqual(mockAuthService.authenticationState, .authenticated)
    }

    func testSignInFailure() async throws {
        mockAuthService.shouldSucceed = false

        await XCTAssertThrowsErrorAsync(
            try await viewModel.signIn(email: "test@example.com", password: "wrong")
        )

        XCTAssertTrue(mockAuthService.signInCalled)
        XCTAssertNil(mockAuthService.currentUser)
    }

    func testSignUpSuccess() async throws {
        mockAuthService.shouldSucceed = true

        try await viewModel.signUp(
            email: "newuser@example.com",
            password: "password123",
            displayName: "New User"
        )

        XCTAssertTrue(mockAuthService.signUpCalled)
        XCTAssertNotNil(mockAuthService.currentUser)
        XCTAssertEqual(mockAuthService.currentUser?.displayName, "New User")
    }

    func testSignUpFailure() async throws {
        mockAuthService.shouldSucceed = false

        await XCTAssertThrowsErrorAsync(
            try await viewModel.signUp(
                email: "newuser@example.com",
                password: "password123",
                displayName: "New User"
            )
        )

        XCTAssertTrue(mockAuthService.signUpCalled)
    }

    func testSignOutSuccess() throws {
        mockAuthService.currentUser = TestDataBuilder.createTestUser()
        mockAuthService.shouldSucceed = true

        try viewModel.signOut()

        XCTAssertTrue(mockAuthService.signOutCalled)
        XCTAssertNil(mockAuthService.currentUser)
        XCTAssertEqual(mockAuthService.authenticationState, .unauthenticated)
    }

    func testSignOutFailure() {
        mockAuthService.currentUser = TestDataBuilder.createTestUser()
        mockAuthService.shouldSucceed = false

        XCTAssertThrowsError(try viewModel.signOut())
        XCTAssertTrue(mockAuthService.signOutCalled)
    }

    func testResetPasswordSuccess() async throws {
        mockAuthService.shouldSucceed = true

        try await viewModel.resetPassword(email: "test@example.com")

        XCTAssertTrue(mockAuthService.resetPasswordCalled)
    }

    func testResetPasswordFailure() async throws {
        mockAuthService.shouldSucceed = false

        await XCTAssertThrowsErrorAsync(
            try await viewModel.resetPassword(email: "test@example.com")
        )

        XCTAssertTrue(mockAuthService.resetPasswordCalled)
    }

    func testAuthenticationStateObservation() {
        let expectation = XCTestExpectation(description: "Authentication state changes")
        var receivedStates: [AuthenticationState] = []

        mockAuthService.$authenticationState
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        mockAuthService.authenticationState = .authenticated

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedStates.count, 2)
        XCTAssertEqual(receivedStates.last, .authenticated)
    }

    func testCurrentUserObservation() {
        let expectation = XCTestExpectation(description: "Current user changes")
        var receivedUsers: [User?] = []

        mockAuthService.$currentUser
            .sink { user in
                receivedUsers.append(user)
                if receivedUsers.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        mockAuthService.currentUser = TestDataBuilder.createTestUser()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedUsers.count, 2)
        XCTAssertNotNil(receivedUsers.last)
    }
}
