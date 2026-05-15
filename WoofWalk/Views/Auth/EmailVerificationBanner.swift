import SwiftUI
import FirebaseAuth

/// Yellow banner mirroring the Android `MainTabView` top-bar prompt that
/// stays visible until the signed-in user verifies their email address.
///
/// Behaviour parity with Android:
///   - Renders **nothing** when the user is signed out or already verified.
///   - On appear (and on tap of "I've verified") we call
///     `Auth.auth().currentUser?.reload()` so the cached `isEmailVerified`
///     flag refreshes — Firebase only mutates this on a fresh fetch, never
///     in-place when the user clicks the link in their inbox.
///   - "Resend" calls `sendEmailVerification()` and shows a transient
///     confirmation. We rate-limit clicks for 60 s to avoid Firebase's
///     `too-many-requests` throttling.
///
/// Wire from `MainTabView` above the `TabView`.
struct EmailVerificationBanner: View {
    @State private var isVerified: Bool = true // assume verified — show nothing until we know otherwise
    @State private var isCheckingNow: Bool = false
    @State private var sendCooldownRemaining: Int = 0
    @State private var statusMessage: String?
    @State private var statusIsError: Bool = false

    /// Re-fire the auth-state check whenever the app foregrounds so a
    /// just-clicked email link clears the banner on return to the app.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if shouldShow {
                bannerBody
            }
        }
        .task {
            await refresh()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await refresh() }
            }
        }
    }

    private var shouldShow: Bool {
        guard let user = Auth.auth().currentUser else { return false }
        // Anonymous users can't verify, so don't nag them.
        guard !user.isAnonymous else { return false }
        // Email-less providers (Apple private relay can be email-bearing,
        // phone-auth is not) shouldn't see this prompt.
        guard let email = user.email, !email.isEmpty else { return false }
        return !isVerified
    }

    private var bannerBody: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Please verify your email")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    if let email = Auth.auth().currentUser?.email {
                        Text("We sent a verification link to \(email).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    if let status = statusMessage {
                        Text(status)
                            .font(.caption2)
                            .foregroundColor(statusIsError ? .red : .green)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(action: handleResend) {
                    HStack(spacing: 4) {
                        if sendCooldownRemaining > 0 {
                            Text("Resend (\(sendCooldownRemaining))")
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.caption)
                            Text("Resend")
                        }
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(sendCooldownRemaining > 0 ? Color.gray : Color.orange))
                }
                .disabled(sendCooldownRemaining > 0)

                Button(action: { Task { await refresh(userInitiated: true) } }) {
                    HStack(spacing: 4) {
                        if isCheckingNow {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.orange)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                        }
                        Text("I've verified")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().stroke(Color.orange, lineWidth: 1.5))
                }
                .disabled(isCheckingNow)

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1.0, green: 0.96, blue: 0.78))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.orange.opacity(0.35)),
            alignment: .bottom
        )
    }

    // MARK: - Actions

    private func handleResend() {
        guard let user = Auth.auth().currentUser, sendCooldownRemaining == 0 else { return }
        user.sendEmailVerification { error in
            if let error = error {
                statusMessage = "Couldn't resend: \(error.localizedDescription)"
                statusIsError = true
            } else {
                statusMessage = "Verification email sent. Check your inbox."
                statusIsError = false
            }
            startCooldown(seconds: 60)
            // Auto-clear the toast after a few seconds.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                if statusMessage != nil { statusMessage = nil }
            }
        }
    }

    /// Pull the current user fresh from the server. Firebase caches
    /// `isEmailVerified` on the local `User` object; the only way to flip
    /// it after the user clicks the inbox link is to call `reload()`.
    private func refresh(userInitiated: Bool = false) async {
        guard let user = Auth.auth().currentUser else {
            await MainActor.run { isVerified = true }
            return
        }
        await MainActor.run { isCheckingNow = userInitiated }
        do {
            try await user.reload()
            let nowVerified = Auth.auth().currentUser?.isEmailVerified ?? false
            await MainActor.run {
                isVerified = nowVerified
                isCheckingNow = false
                if userInitiated {
                    if nowVerified {
                        statusMessage = "Email verified — thank you!"
                        statusIsError = false
                    } else {
                        statusMessage = "Still unverified. Did you click the link?"
                        statusIsError = true
                    }
                }
            }
        } catch {
            await MainActor.run {
                isCheckingNow = false
                if userInitiated {
                    statusMessage = "Couldn't check: \(error.localizedDescription)"
                    statusIsError = true
                }
            }
        }
    }

    private func startCooldown(seconds: Int) {
        sendCooldownRemaining = seconds
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                if sendCooldownRemaining > 0 {
                    sendCooldownRemaining -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}
