import SwiftUI

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let label: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            HStack {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 20)

                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(error != nil ? Color.red : Color.clear, lineWidth: 1)
            )

            if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct CustomPasswordField: View {
    @Binding var text: String
    let placeholder: String
    let label: String
    var error: String?

    @State private var isSecured = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .frame(width: 20)

                if isSecured {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Button(action: {
                    isSecured.toggle()
                }) {
                    Image(systemName: isSecured ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(error != nil ? Color.red : Color.clear, lineWidth: 1)
            )

            if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "pawprint.fill")
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isLoading ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

struct DividerWithText: View {
    let text: String

    var body: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
        }
    }
}

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text(message)
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(32)
            .background(Color(.systemGray5))
            .cornerRadius(16)
        }
    }
}
