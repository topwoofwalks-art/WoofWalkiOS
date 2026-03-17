import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.colorScheme) var colorScheme

    let onNavigateToSignup: () -> Void
    let onNavigateToForgotPassword: () -> Void
    let onLoginSuccess: () -> Void

    @State private var showBiometricButton = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)
                    loginHeader
                    loginFormFields
                    loginButtons
                    DividerWithText(text: "OR")
                        .padding(.horizontal)
                    socialSignInSection
                    signupLink
                    Spacer(minLength: 40)
                }
            }

            if viewModel.loginUiState.isLoading {
                LoadingOverlay(message: "Signing in...")
            }
        }
        .onAppear { checkBiometricAvailability() }
        .onChange(of: viewModel.authState) { newState in
            if case .authenticated = newState { onLoginSuccess() }
        }
    }

    // MARK: - Sub-views

    private var loginHeader: some View {
        VStack(spacing: 8) {
            Text("Welcome to WoofWalk")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Text("Sign in to continue your walk")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 16)
    }

    private var loginFormFields: some View {
        VStack(spacing: 16) {
            CustomTextField(
                text: Binding(
                    get: { viewModel.loginUiState.email },
                    set: { viewModel.updateLoginEmail($0) }
                ),
                placeholder: "your@email.com",
                label: "Email",
                icon: "envelope",
                keyboardType: .emailAddress,
                error: viewModel.loginUiState.emailError
            )

            CustomPasswordField(
                text: Binding(
                    get: { viewModel.loginUiState.password },
                    set: { viewModel.updateLoginPassword($0) }
                ),
                placeholder: "Password",
                label: "Password",
                error: viewModel.loginUiState.passwordError
            )

            if let errorMessage = viewModel.loginUiState.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button(action: onNavigateToForgotPassword) {
                    Text("Forgot password?")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal)
    }

    private var loginButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(
                title: "Sign In",
                isLoading: viewModel.loginUiState.isLoading,
                action: viewModel.login
            )
            .padding(.horizontal)

            if showBiometricButton && BiometricAuthManager.shared.hasStoredCredentials() {
                BiometricButton(action: { viewModel.signInWithBiometric() })
                    .padding(.horizontal)
            }
        }
    }

    private var socialSignInSection: some View {
        VStack(spacing: 12) {
            GoogleSignInButton(action: {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    viewModel.signInWithGoogle(presentingViewController: rootViewController)
                }
            })
            .padding(.horizontal)

            AppleSignInButton(
                viewModel: viewModel,
                onSuccess: { onLoginSuccess() }
            )
            .frame(height: 50)
            .padding(.horizontal)
        }
    }

    private var signupLink: some View {
        HStack {
            Text("Don't have an account?")
                .font(.body)
            Button(action: onNavigateToSignup) {
                Text("Sign Up")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.top, 8)
    }

    private func checkBiometricAvailability() {
        Task {
            showBiometricButton = await BiometricAuthManager.shared.isBiometricAvailable()
        }
    }
}

struct BiometricButton: View {
    let action: () -> Void

    private var biometricType: BiometricType {
        BiometricAuthManager.shared.getBiometricType()
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.shield"
        }
    }

    private var biometricText: String {
        switch biometricType {
        case .faceID:
            return "Sign in with Face ID"
        case .touchID:
            return "Sign in with Touch ID"
        case .opticID:
            return "Sign in with Optic ID"
        case .none:
            return "Sign in with Biometric"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: biometricIcon)
                    .font(.system(size: 20))
                Text(biometricText)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

struct AppleSignInButton: View {
    @ObservedObject var viewModel: AuthViewModel
    let onSuccess: () -> Void

    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
                request.nonce = viewModel.getAppleSignInNonce()
            },
            onCompletion: { result in
                switch result {
                case .success(let authorization):
                    viewModel.signInWithApple(authorization: authorization)
                case .failure(let error):
                    print("Apple Sign In failed: \(error.localizedDescription)")
                }
            }
        )
        .signInWithAppleButtonStyle(.black)
        .cornerRadius(12)
    }
}

struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 20))
                Text("Sign in with Google")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
