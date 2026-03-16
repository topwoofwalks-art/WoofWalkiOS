import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

enum AuthError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case invalidEmail
    case userDisabled
    case googleSignInFailed
    case appleSignInFailed
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "No account found with this email"
        case .emailAlreadyInUse:
            return "Account already exists with this email"
        case .weakPassword:
            return "Password is too weak"
        case .networkError:
            return "Network error. Please check your connection"
        case .invalidEmail:
            return "Invalid email format"
        case .userDisabled:
            return "This account has been disabled"
        case .googleSignInFailed:
            return "Google sign-in failed"
        case .appleSignInFailed:
            return "Apple sign-in failed"
        case .unknownError(let message):
            return message
        }
    }
}

class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false

    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    private override init() {
        super.init()
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await syncUserData(userId: result.user.uid)
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func signUpWithEmail(email: String, password: String, username: String) async throws -> User {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let user = result.user

            try await createUserProfile(userId: user.uid, email: email, username: username)

            return user
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func signInWithGoogle(presentingViewController: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.googleSignInFailed
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.googleSignInFailed
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await auth.signIn(with: credential)
            let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false

            if isNewUser {
                let username = result.user.profile?.name ?? "User"
                let email = result.user.profile?.email ?? ""
                try await createUserProfile(userId: authResult.user.uid, email: email, username: username)
            }

            await syncUserData(userId: authResult.user.uid)
        } catch {
            throw AuthError.googleSignInFailed
        }
    }

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.appleSignInFailed
        }

        guard let nonce = currentNonce else {
            throw AuthError.appleSignInFailed
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthError.appleSignInFailed
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.appleSignInFailed
        }

        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: nonce
        )

        do {
            let authResult = try await auth.signIn(with: credential)
            let isNewUser = authResult.additionalUserInfo?.isNewUser ?? false

            if isNewUser {
                let fullName = appleIDCredential.fullName
                let username = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .isEmpty ? "User" : [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")

                let email = appleIDCredential.email ?? authResult.user.email ?? ""
                try await createUserProfile(userId: authResult.user.uid, email: email, username: username)
            }

            await syncUserData(userId: authResult.user.uid)
        } catch {
            throw AuthError.appleSignInFailed
        }
    }

    func signInAnonymously() async throws {
        do {
            try await auth.signInAnonymously()
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func linkAnonymousToEmail(email: String, password: String, username: String) async throws {
        guard let user = auth.currentUser, user.isAnonymous else {
            throw AuthError.invalidCredentials
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            try await user.link(with: credential)
            try await createUserProfile(userId: user.uid, email: email, username: username)
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func sendEmailVerification() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }

        do {
            try await user.sendEmailVerification()
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func reloadUser() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }

        try await user.reload()
    }

    func updatePassword(newPassword: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }

        do {
            try await user.updatePassword(to: newPassword)
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func reauthenticate(email: String, password: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            try await user.reauthenticate(with: credential)
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func signOut() throws {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()

            KeychainManager.shared.deleteToken(forKey: "authToken")
            KeychainManager.shared.deleteToken(forKey: "refreshToken")
        } catch {
            throw AuthError.unknownError("Sign out failed")
        }
    }

    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }

        let userId = user.uid

        do {
            try await firestore.collection("users").document(userId).delete()
            try await user.delete()

            KeychainManager.shared.deleteToken(forKey: "authToken")
            KeychainManager.shared.deleteToken(forKey: "refreshToken")
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    func refreshToken() async throws -> String {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }

        do {
            let token = try await user.getIDToken()
            KeychainManager.shared.saveToken(token, forKey: "authToken")
            return token
        } catch {
            throw AuthError.unknownError("Failed to refresh token")
        }
    }

    func startAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    private func createUserProfile(userId: String, email: String, username: String) async throws {
        let userData: [String: Any] = [
            "id": userId,
            "username": username,
            "email": email,
            "photoUrl": NSNull(),
            "pawPoints": 0,
            "level": 1,
            "badges": [],
            "dogs": [],
            "createdAt": FieldValue.serverTimestamp(),
            "regionCode": Locale.current.region?.identifier ?? "US"
        ]

        try await firestore.collection("users").document(userId).setData(userData)
    }

    private func syncUserData(userId: String) async {
        do {
            let token = try await auth.currentUser?.getIDToken() ?? ""
            KeychainManager.shared.saveToken(token, forKey: "authToken")
        } catch {
            print("Failed to sync user data: \(error.localizedDescription)")
        }
    }

    private func mapAuthError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode.Code(rawValue: error.code) else {
            return .unknownError(error.localizedDescription)
        }

        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkError
        case .userDisabled:
            return .userDisabled
        default:
            return .unknownError(error.localizedDescription)
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}
