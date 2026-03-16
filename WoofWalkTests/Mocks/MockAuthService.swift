import Foundation
import FirebaseAuth
import Combine
@testable import WoofWalk

class MockAuthService: AuthServiceProtocol {
    @Published var currentUser: User?
    @Published var authenticationState: AuthenticationState = .unauthenticated

    var currentUserPublisher: AnyPublisher<User?, Never> {
        $currentUser.eraseToAnyPublisher()
    }

    var authenticationStatePublisher: AnyPublisher<AuthenticationState, Never> {
        $authenticationState.eraseToAnyPublisher()
    }

    var shouldSucceed = true
    var signInCalled = false
    var signUpCalled = false
    var signOutCalled = false
    var resetPasswordCalled = false

    func signIn(email: String, password: String) async throws {
        signInCalled = true
        guard shouldSucceed else {
            throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sign in failed"])
        }

        let user = User(
            id: "test-user-123",
            email: email,
            displayName: "Test User",
            createdAt: Date()
        )

        await MainActor.run {
            self.currentUser = user
            self.authenticationState = .authenticated
        }
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        signUpCalled = true
        guard shouldSucceed else {
            throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sign up failed"])
        }

        let user = User(
            id: "test-user-456",
            email: email,
            displayName: displayName,
            createdAt: Date()
        )

        await MainActor.run {
            self.currentUser = user
            self.authenticationState = .authenticated
        }
    }

    func signOut() throws {
        signOutCalled = true
        guard shouldSucceed else {
            throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sign out failed"])
        }

        currentUser = nil
        authenticationState = .unauthenticated
    }

    func resetPassword(email: String) async throws {
        resetPasswordCalled = true
        guard shouldSucceed else {
            throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Password reset failed"])
        }
    }

    func updateProfile(displayName: String?, photoURL: URL?) async throws {
        guard shouldSucceed else {
            throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Profile update failed"])
        }

        if var user = currentUser {
            if let displayName = displayName {
                user.displayName = displayName
            }
            currentUser = user
        }
    }
}
