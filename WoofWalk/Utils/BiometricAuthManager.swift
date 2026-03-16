import Foundation
import LocalAuthentication

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
}

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case authenticationFailed
    case userCancel
    case userFallback
    case biometryLockout
    case credentialsNotFound

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available"
        case .notEnrolled:
            return "No biometric credentials enrolled"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .userCancel:
            return "Authentication was cancelled"
        case .userFallback:
            return "User chose to use password"
        case .biometryLockout:
            return "Biometric authentication is locked out"
        case .credentialsNotFound:
            return "No saved credentials found"
        }
    }
}

class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private let context = LAContext()
    private let keychainManager = KeychainManager.shared

    private init() {}

    func getBiometricType() -> BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }

    func isBiometricAvailable() async -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate() async throws -> (email: String, password: String) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw mapBiometricError(error)
            }
            throw BiometricError.notAvailable
        }

        let reason = getBiometricReason()

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                guard let credentials = keychainManager.getCredentials() else {
                    throw BiometricError.credentialsNotFound
                }
                return credentials
            } else {
                throw BiometricError.authenticationFailed
            }
        } catch {
            throw mapBiometricError(error as NSError)
        }
    }

    func saveCredentials(email: String, password: String) async throws {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw mapBiometricError(error)
            }
            throw BiometricError.notAvailable
        }

        let reason = "Enable \(getBiometricTypeName()) for quick sign-in"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                keychainManager.saveCredentials(email: email, password: password)
            } else {
                throw BiometricError.authenticationFailed
            }
        } catch {
            throw mapBiometricError(error as NSError)
        }
    }

    func deleteCredentials() {
        keychainManager.deleteCredentials()
    }

    func hasStoredCredentials() -> Bool {
        return keychainManager.getCredentials() != nil
    }

    private func getBiometricReason() -> String {
        switch getBiometricType() {
        case .faceID:
            return "Use Face ID to sign in to WoofWalk"
        case .touchID:
            return "Use Touch ID to sign in to WoofWalk"
        case .opticID:
            return "Use Optic ID to sign in to WoofWalk"
        case .none:
            return "Authenticate to sign in to WoofWalk"
        }
    }

    private func getBiometricTypeName() -> String {
        switch getBiometricType() {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometric Authentication"
        }
    }

    private func mapBiometricError(_ error: NSError) -> BiometricError {
        guard let laError = error as? LAError else {
            return .authenticationFailed
        }

        switch laError.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .biometryLockout:
            return .biometryLockout
        case .authenticationFailed:
            return .authenticationFailed
        default:
            return .authenticationFailed
        }
    }
}
