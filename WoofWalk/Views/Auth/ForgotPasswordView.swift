import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.presentationMode) var presentationMode

    @State private var email = ""
    @State private var emailError: String?
    @State private var successMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Forgot your password?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Text("Enter your email address and we'll send you instructions to reset your password.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 16)

            VStack(spacing: 16) {
                CustomTextField(
                    text: $email,
                    placeholder: "your@email.com",
                    label: "Email",
                    icon: "envelope",
                    keyboardType: .emailAddress,
                    error: emailError
                )
                .onChange(of: email) { _ in
                    emailError = nil
                    successMessage = nil
                }

                if let successMessage = successMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal)

            PrimaryButton(
                title: "Send Reset Link",
                isLoading: false,
                action: sendResetLink
            )
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendResetLink() {
        if email.isEmpty {
            emailError = "Email is required"
            return
        }

        if !isValidEmail(email) {
            emailError = "Invalid email format"
            return
        }

        viewModel.resetPassword(email: email)
        successMessage = "Password reset link sent to \(email)"
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
