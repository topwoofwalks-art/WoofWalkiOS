import Foundation
import SwiftUI
import FirebaseAuth
import AuthenticationServices

enum AuthState: Equatable {
    case initial
    case loading
    case authenticated
    case unauthenticated
    case error(String)
}

struct LoginUiState {
    var email: String = ""
    var password: String = ""
    var emailError: String?
    var passwordError: String?
    var isLoading: Bool = false
    var errorMessage: String?
}

struct SignupUiState {
    var email: String = ""
    var username: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var emailError: String?
    var usernameError: String?
    var passwordError: String?
    var confirmPasswordError: String?
    var isLoading: Bool = false
    var errorMessage: String?
}

struct DogFormData: Identifiable {
    let id: String = UUID().uuidString
    var name: String = ""
    var breed: String = ""
    var age: String = ""
}

struct ProfileSetupUiState {
    var displayName: String = ""
    var bio: String = ""
    var dogs: [DogFormData] = [DogFormData()]
    var isLoading: Bool = false
    var errorMessage: String?
}

@MainActor
class AuthViewModel: NSObject, ObservableObject {
    @Published var authState: AuthState = .initial
    @Published var loginUiState = LoginUiState()
    @Published var signupUiState = SignupUiState()
    @Published var profileSetupUiState = ProfileSetupUiState()

    private let authService = AuthService.shared
    private let biometricAuth = BiometricAuthManager.shared

    override init() {
        super.init()
        checkAuthState()
    }

    private func checkAuthState() {
        if authService.currentUser != nil {
            authState = .authenticated
        } else {
            authState = .unauthenticated
        }
    }

    func updateLoginEmail(_ email: String) {
        loginUiState.email = email
        loginUiState.emailError = nil
    }

    func updateLoginPassword(_ password: String) {
        loginUiState.password = password
        loginUiState.passwordError = nil
    }

    func updateSignupEmail(_ email: String) {
        signupUiState.email = email
        signupUiState.emailError = nil
    }

    func updateSignupUsername(_ username: String) {
        signupUiState.username = username
        signupUiState.usernameError = nil
    }

    func updateSignupPassword(_ password: String) {
        signupUiState.password = password
        signupUiState.passwordError = nil
    }

    func updateSignupConfirmPassword(_ confirmPassword: String) {
        signupUiState.confirmPassword = confirmPassword
        signupUiState.confirmPasswordError = nil
    }

    func clearSignupState() {
        signupUiState = SignupUiState()
    }

    func clearLoginState() {
        loginUiState = LoginUiState()
    }

    func login() {
        let email = loginUiState.email
        let password = loginUiState.password

        guard validateLoginInput(email: email, password: password) else { return }

        Task {
            do {
                loginUiState.isLoading = true
                loginUiState.errorMessage = nil

                try await authService.signInWithEmail(email: email, password: password)

                loginUiState.isLoading = false
                authState = .authenticated

                if await biometricAuth.isBiometricAvailable() {
                    try? await biometricAuth.saveCredentials(email: email, password: password)
                }
            } catch let error as AuthError {
                loginUiState.isLoading = false
                loginUiState.errorMessage = error.errorDescription
            } catch {
                loginUiState.isLoading = false
                loginUiState.errorMessage = "Login failed"
            }
        }
    }

    func signup() {
        let email = signupUiState.email
        let username = signupUiState.username
        let password = signupUiState.password
        let confirmPassword = signupUiState.confirmPassword

        guard validateSignupInput(
            email: email,
            username: username,
            password: password,
            confirmPassword: confirmPassword
        ) else { return }

        Task {
            do {
                signupUiState.isLoading = true
                signupUiState.errorMessage = nil

                _ = try await authService.signUpWithEmail(
                    email: email,
                    password: password,
                    username: username
                )

                signupUiState.isLoading = false
                authState = .authenticated
            } catch let error as AuthError {
                signupUiState.isLoading = false
                handleSignupError(error)
            } catch {
                signupUiState.isLoading = false
                signupUiState.errorMessage = "Signup failed"
            }
        }
    }

    func signInWithGoogle(presentingViewController: UIViewController) {
        Task {
            do {
                loginUiState.isLoading = true
                loginUiState.errorMessage = nil
                authState = .loading

                try await authService.signInWithGoogle(presentingViewController: presentingViewController)

                loginUiState.isLoading = false
                authState = .authenticated
            } catch {
                loginUiState.isLoading = false
                loginUiState.errorMessage = "Google sign-in failed. Please try again or use email sign-in."
                authState = .error("Google sign-in failed")
            }
        }
    }

    func signInWithApple(authorization: ASAuthorization) {
        Task {
            do {
                loginUiState.isLoading = true
                loginUiState.errorMessage = nil
                authState = .loading

                try await authService.signInWithApple(authorization: authorization)

                loginUiState.isLoading = false
                authState = .authenticated
            } catch {
                loginUiState.isLoading = false
                loginUiState.errorMessage = "Apple sign-in failed. Please try again or use email sign-in."
                authState = .error("Apple sign-in failed")
            }
        }
    }

    func signInWithBiometric() {
        Task {
            do {
                loginUiState.isLoading = true
                loginUiState.errorMessage = nil

                let credentials = try await biometricAuth.authenticate()

                try await authService.signInWithEmail(
                    email: credentials.email,
                    password: credentials.password
                )

                loginUiState.isLoading = false
                authState = .authenticated
            } catch {
                loginUiState.isLoading = false
                loginUiState.errorMessage = "Biometric authentication failed"
            }
        }
    }

    func resetPassword(email: String) {
        Task {
            do {
                try await authService.sendPasswordReset(email: email)
            } catch {
                authState = .error("Password reset failed")
            }
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            authState = .unauthenticated
            loginUiState = LoginUiState()
            signupUiState = SignupUiState()
        } catch {
            authState = .error("Sign out failed")
        }
    }

    func sendEmailVerification() {
        Task {
            do {
                try await authService.sendEmailVerification()
            } catch {
                print("Failed to send email verification: \(error.localizedDescription)")
            }
        }
    }

    func updateProfileDisplayName(_ name: String) {
        profileSetupUiState.displayName = name
    }

    func updateProfileBio(_ bio: String) {
        profileSetupUiState.bio = bio
    }

    func updateDogName(dogId: String, name: String) {
        if let index = profileSetupUiState.dogs.firstIndex(where: { $0.id == dogId }) {
            profileSetupUiState.dogs[index].name = name
        }
    }

    func updateDogBreed(dogId: String, breed: String) {
        if let index = profileSetupUiState.dogs.firstIndex(where: { $0.id == dogId }) {
            profileSetupUiState.dogs[index].breed = breed
        }
    }

    func updateDogAge(dogId: String, age: String) {
        if let index = profileSetupUiState.dogs.firstIndex(where: { $0.id == dogId }) {
            profileSetupUiState.dogs[index].age = age
        }
    }

    func addDog() {
        profileSetupUiState.dogs.append(DogFormData())
    }

    func removeDog(dogId: String) {
        if profileSetupUiState.dogs.count > 1 {
            profileSetupUiState.dogs.removeAll { $0.id == dogId }
        }
    }

    private func validateLoginInput(email: String, password: String) -> Bool {
        var isValid = true

        if email.isEmpty {
            loginUiState.emailError = "Email is required"
            isValid = false
        } else if !isValidEmail(email) {
            loginUiState.emailError = "Invalid email format"
            isValid = false
        }

        if password.isEmpty {
            loginUiState.passwordError = "Password is required"
            isValid = false
        }

        return isValid
    }

    private func validateSignupInput(
        email: String,
        username: String,
        password: String,
        confirmPassword: String
    ) -> Bool {
        var isValid = true

        if email.isEmpty {
            signupUiState.emailError = "Email is required"
            isValid = false
        } else if !isValidEmail(email) {
            signupUiState.emailError = "Invalid email format"
            isValid = false
        }

        if username.isEmpty {
            signupUiState.usernameError = "Username is required"
            isValid = false
        } else if username.count < 3 {
            signupUiState.usernameError = "Username must be at least 3 characters"
            isValid = false
        }

        if password.isEmpty {
            signupUiState.passwordError = "Password is required"
            isValid = false
        } else if password.count < 6 {
            signupUiState.passwordError = "Password must be at least 6 characters"
            isValid = false
        }

        if confirmPassword != password {
            signupUiState.confirmPasswordError = "Passwords do not match"
            isValid = false
        }

        return isValid
    }

    private func handleSignupError(_ error: AuthError) {
        switch error {
        case .weakPassword:
            signupUiState.passwordError = "Password is too weak"
        case .emailAlreadyInUse:
            signupUiState.emailError = "Account already exists with this email"
        case .invalidEmail:
            signupUiState.emailError = "Invalid email format"
        default:
            signupUiState.errorMessage = error.errorDescription
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    func getAppleSignInNonce() -> String {
        return authService.startAppleSignIn()
    }

    var currentUser: FirebaseAuth.User? {
        return authService.currentUser
    }
}

extension AuthViewModel: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            signInWithApple(authorization: authorization)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            loginUiState.isLoading = false
            loginUiState.errorMessage = "Apple sign-in was cancelled or failed"
        }
    }
}
