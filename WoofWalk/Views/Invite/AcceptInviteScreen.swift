import SwiftUI
import FirebaseAuth
import FirebaseFunctions

/// AcceptInviteScreen — iOS counterpart to the portal's
/// `AcceptInvitePage.tsx` (`/accept-invite?token=<invitationId>`).
///
/// Flow:
///   1. If signed out → tell user to sign in (they can already do that
///      from the auth root); we don't have a returnTo bouncer in the
///      iOS shell yet, so the deeplink lands on this screen and the
///      caller has to authenticate first. The screen polls
///      `Auth.auth().currentUser` once on appear and re-checks when the
///      view is brought back into focus.
///   2. Once auth'd, call `acceptTeamInvitation` (Cloud Function in
///      `europe-west2`). On success, force a token refresh so the new
///      role/orgId claims propagate through to subsequent reads, then
///      navigate to the business dashboard.
///   3. On failure, show the structured error from the CF — the
///      auditor-facing cases are: expired, wrong email (the CF binds
///      invitations to the recipient's email at creation time and
///      refuses if the auth'd user's email doesn't match), already
///      member of another org.
///
/// Brand-locked dark mode — the app is single-mode (Info.plist
/// `UIUserInterfaceStyle = Dark`), so no light variants here.
struct AcceptInviteScreen: View {
    let token: String

    @StateObject private var navigator = AppNavigator.shared
    @State private var phase: Phase = .signingIn
    @State private var errorMessage: String?

    private let functions = Functions.functions(region: "europe-west2")

    enum Phase {
        case signingIn   // not auth'd yet — show CTA to sign in
        case accepting   // CF is running
        case success     // accepted, brief confirmation before route
        case failure     // CF rejected, error visible
    }

    var body: some View {
        ZStack {
            Color.neutral10.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Brand mark — Apple paw, turquoise60 to match logo accent.
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.turquoise60)

                Text("Team invitation")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.neutral90)

                content
                    .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await runFlow()
        }
    }

    // MARK: - Phase content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .signingIn:
            VStack(spacing: 12) {
                Text("Sign in with the email this invitation was sent to, then re-open the link.")
                    .font(.body)
                    .foregroundColor(.neutral80)
                    .multilineTextAlignment(.center)
                Button {
                    // Best we can do without a returnTo bouncer is pop
                    // the user back to root — the auth root view will
                    // pick up unauthenticated state and show the login
                    // screen. They can re-tap the deeplink afterwards.
                    navigator.popToRoot()
                } label: {
                    Text("Take me to sign in")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.turquoise60)
                        .foregroundColor(.neutral10)
                        .cornerRadius(10)
                }
            }

        case .accepting:
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.turquoise60)
                Text("Accepting your invitation…")
                    .font(.subheadline)
                    .foregroundColor(.neutral80)
            }

        case .success:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.success60)
                Text("You're in. Taking you to the team dashboard…")
                    .font(.body)
                    .foregroundColor(.neutral90)
                    .multilineTextAlignment(.center)
            }

        case .failure:
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: 0xFFB74D))
                Text(errorMessage ?? "Failed to accept invitation")
                    .font(.body)
                    .foregroundColor(.neutral90)
                    .multilineTextAlignment(.center)
                Text("Invitations expire after 7 days and are tied to the email address they were sent to. Ask the sender to resend if needed.")
                    .font(.caption)
                    .foregroundColor(.neutral70)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        // Sign out and bounce home — the user's current
                        // auth identity didn't match the invite. Most
                        // likely cause: invite went to a different email.
                        try? Auth.auth().signOut()
                        navigator.popToRoot()
                    }
                } label: {
                    Text("Sign in with a different account")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.turquoise60)
                        .foregroundColor(.neutral10)
                        .cornerRadius(10)
                }
            }
        }
    }

    // MARK: - Flow

    private func runFlow() async {
        guard !token.isEmpty else {
            errorMessage = "Missing invitation token"
            phase = .failure
            return
        }
        guard Auth.auth().currentUser != nil else {
            phase = .signingIn
            return
        }
        phase = .accepting

        do {
            let result = try await functions
                .httpsCallable("acceptTeamInvitation")
                .call(["invitationId": token])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool, success else {
                errorMessage = "Invitation could not be accepted"
                phase = .failure
                return
            }

            // CF returns requiresTokenRefresh: true on success — refresh
            // so the new role/orgId custom claims propagate to subsequent
            // Firestore reads. Mirrors portal AcceptInvitePage.
            if let needsRefresh = data["requiresTokenRefresh"] as? Bool,
               needsRefresh,
               let user = Auth.auth().currentUser {
                _ = try? await user.getIDTokenResult(forcingRefresh: true)
            }

            phase = .success
            // Brief confirmation pause so the user can read the message
            // before we route. Mirrors portal's 1.5s setTimeout.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            navigator.popToRoot()
            navigator.switchMode(.business)
            navigator.navigate(to: .businessDashboard)
        } catch {
            // Surface the CF's structured error message — the typical
            // cases (`already-exists` on cross-org, `permission-denied`
            // on email mismatch, `not-found` on expired) all include
            // human-readable copy from the server side.
            errorMessage = (error as NSError).localizedDescription
            phase = .failure
        }
    }
}
