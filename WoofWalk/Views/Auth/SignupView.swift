import SwiftUI
import AuthenticationServices

struct SignupView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode

    let onNavigateToLogin: () -> Void
    let onSignupSuccess: () -> Void

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    headerSection
                    signupFormFields
                    signupButton
                    socialSignInSection
                    loginLink
                    Spacer(minLength: 40)
                }
            }

            if viewModel.signupUiState.isLoading {
                LoadingOverlay(message: "Creating your account...")
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            viewModel.clearSignupState()
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        })
        .onDisappear { viewModel.clearSignupState() }
        .onChange(of: viewModel.authState) { newState in
            if case .authenticated = newState { onSignupSuccess() }
        }
    }

    // MARK: - Sub-views

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Join WoofWalk")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Text("Create an account to start your adventure")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 16)
    }

    private var signupFormFields: some View {
        VStack(spacing: 16) {
            CustomTextField(
                text: Binding(
                    get: { viewModel.signupUiState.email },
                    set: { viewModel.updateSignupEmail($0) }
                ),
                placeholder: "your@email.com",
                label: "Email",
                icon: "envelope",
                keyboardType: .emailAddress,
                error: viewModel.signupUiState.emailError
            )

            CustomTextField(
                text: Binding(
                    get: { viewModel.signupUiState.username },
                    set: { viewModel.updateSignupUsername($0) }
                ),
                placeholder: "dogwalker123",
                label: "Username",
                icon: "person.circle",
                error: viewModel.signupUiState.usernameError
            )

            CustomPasswordField(
                text: Binding(
                    get: { viewModel.signupUiState.password },
                    set: { viewModel.updateSignupPassword($0) }
                ),
                placeholder: "At least 6 characters",
                label: "Password",
                error: viewModel.signupUiState.passwordError
            )

            CustomPasswordField(
                text: Binding(
                    get: { viewModel.signupUiState.confirmPassword },
                    set: { viewModel.updateSignupConfirmPassword($0) }
                ),
                placeholder: "Re-enter password",
                label: "Confirm Password",
                error: viewModel.signupUiState.confirmPasswordError
            )

            Toggle(isOn: $viewModel.marketingOptIn) {
                Text("Send me tips, offers & dog walking news")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .tint(.blue)

            if let errorMessage = viewModel.signupUiState.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }

    private var signupButton: some View {
        VStack(spacing: 16) {
            PrimaryButton(
                title: "Sign Up",
                isLoading: viewModel.signupUiState.isLoading,
                action: viewModel.signup
            )
            .padding(.horizontal)

            DividerWithText(text: "OR")
                .padding(.horizontal)
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
                onSuccess: { onSignupSuccess() }
            )
            .frame(height: 50)
            .padding(.horizontal)
        }
    }

    private var loginLink: some View {
        HStack {
            Text("Already have an account?")
                .font(.body)
            Button(action: onNavigateToLogin) {
                Text("Sign In")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.top, 8)
    }
}
