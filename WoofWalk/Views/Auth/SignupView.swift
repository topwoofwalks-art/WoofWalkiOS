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
                LoadingOverlay(message: String(localized: "creating_account"))
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            viewModel.clearSignupState()
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text(String(localized: "action_back"))
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
            Text(String(localized: "signup_title"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Text(String(localized: "signup_subtitle"))
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
                placeholder: String(localized: "signup_email_placeholder"),
                label: String(localized: "signup_email_label"),
                icon: "envelope",
                keyboardType: .emailAddress,
                error: viewModel.signupUiState.emailError
            )

            CustomTextField(
                text: Binding(
                    get: { viewModel.signupUiState.username },
                    set: { viewModel.updateSignupUsername($0) }
                ),
                placeholder: String(localized: "signup_username_placeholder"),
                label: String(localized: "signup_username_label"),
                icon: "person.circle",
                error: viewModel.signupUiState.usernameError
            )

            CustomPasswordField(
                text: Binding(
                    get: { viewModel.signupUiState.password },
                    set: { viewModel.updateSignupPassword($0) }
                ),
                placeholder: String(localized: "signup_password_placeholder"),
                label: String(localized: "signup_password_label"),
                error: viewModel.signupUiState.passwordError
            )

            CustomPasswordField(
                text: Binding(
                    get: { viewModel.signupUiState.confirmPassword },
                    set: { viewModel.updateSignupConfirmPassword($0) }
                ),
                placeholder: String(localized: "signup_confirm_password_placeholder"),
                label: String(localized: "signup_confirm_password_label"),
                error: viewModel.signupUiState.confirmPasswordError
            )

            Toggle(isOn: $viewModel.marketingOptIn) {
                Text(String(localized: "signup_marketing_opt_in"))
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
                title: String(localized: "signup_button"),
                isLoading: viewModel.signupUiState.isLoading,
                action: viewModel.signup
            )
            .padding(.horizontal)

            DividerWithText(text: String(localized: "signup_or_divider"))
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
            Text(String(localized: "signup_already_have_account"))
                .font(.body)
            Button(action: onNavigateToLogin) {
                Text(String(localized: "signup_sign_in_link"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.top, 8)
    }
}
