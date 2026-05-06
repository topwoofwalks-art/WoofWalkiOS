import SwiftUI
import Firebase
import FirebaseAuth
import StripePaymentSheet
import GoogleMobileAds

@main
struct WoofWalkApp: App {
    // Mount a tiny UIKit delegate purely so the Branch SDK can hook
    // into `didFinishLaunchingWithOptions`, `application(_:continue:)`,
    // and `application(_:open:options:)` — none of which are surfaced
    // by SwiftUI's pure-App lifecycle. The delegate forwards those
    // callbacks to BranchReferralService, which falls through to the
    // existing `.onOpenURL` deeplink router for non-Branch URLs.
    @UIApplicationDelegateAdaptor(BranchAppDelegate.self) private var branchAppDelegate

    @StateObject private var screenshotAutomation = ScreenshotAutomation.shared
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        } else {
            print("[WoofWalk] GoogleService-Info.plist not found - Firebase disabled")
        }

        // Branch.io referral attribution — initialise the SDK before
        // the first scene appears so the deferred deep-link callback
        // fires during cold start. Mirrors Android's
        // `ReferralAttribution` self-hosted attribution flow: Branch
        // is iOS's source for the "user clicked an invite link before
        // installing" payload, the equivalent of Play Install Referrer
        // on Android. The service short-circuits if the BranchKey
        // Info.plist value is the `BRANCH_KEY_NEEDED` placeholder, so
        // dev builds without keys still launch cleanly.
        BranchReferralService.shared.configure()

        // Stripe SDK — full PaymentSheet parity with Android. The publishable
        // key is hard-coded to match Android's `WoofWalkApplication.kt`
        // (the live key for the WoofWalk Stripe account). PaymentIntents
        // are created server-side by `processBookingPayment`; the
        // PaymentSheet client only needs the publishable key + clientSecret.
        StripeAPI.defaultPublishableKey = "pk_live_51Sg8grCHt9yHTLb1wpKwVN5LyUR93kgUYJmjxs5NrD4rHXGyFuAnyskiQYCRZKQNJVALvnnHeZol3Xv8gaIIF0aD00NoVlE74t"

        // Google Mobile Ads (AdMob) — gates the charity-points award.
        // Must run before the first preloadAd() call. The completion
        // closure fires when the SDK is ready to serve ads; we don't
        // block on it because preloadAd() itself queues until ready.
        // Mirrors Android's MobileAds.initialize(...) on app start.
        MobileAds.shared.start { _ in
            print("[WoofWalk] AdMob initialised")
        }

        NotificationService.shared.configure()

        // Phone-side WatchConnectivity bridge — receives SOS / DMS-OK
        // / car-save / quick-reply messages from the Watch app and
        // writes them to Firestore. Must be activated early so any
        // pending message queued on the Watch (during a window when
        // the phone wasn't running) flushes through.
        PhoneWatchSessionManager.shared.activate()
    }

    private var isTestMode: Bool {
        screenshotAutomation.isScreenshotMode || screenshotAutomation.isFullTestMode
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .onChange(of: authViewModel.authState) { newState in
                    if case .authenticated = newState {
                        // Pre-fill display name from the auth provider
                        if let user = authViewModel.currentUser {
                            if authViewModel.profileSetupUiState.displayName.isEmpty,
                               let name = user.displayName, !name.isEmpty {
                                authViewModel.updateProfileDisplayName(name)
                            }
                        }
                        authViewModel.checkProfileExists()

                        // Self-hosted referral attribution. One-shot,
                        // post-sign-in: takes any Branch-supplied
                        // referral code stashed in UserDefaults and
                        // forwards it to the `attributeInstall` Cloud
                        // Function which writes
                        // `users/{uid}.referredBy` and creates the
                        // `referrals/{id}` doc. Idempotent — only
                        // runs once per install. Mirrors Android's
                        // `referralAttribution.attributeIfNeeded()`
                        // call in `MainActivity.onCreate`.
                        Task {
                            await BranchReferralService.shared.attributeIfNeeded()
                        }
                    }
                }
                .onOpenURL { url in
                    // Custom-scheme deeplinks (woofwalk://...). Routes
                    // are dispatched on the main actor so Navigator
                    // mutations land on the same hop as the SwiftUI
                    // path/tab bindings. Unknown hosts are silently
                    // ignored — never crash on an unrecognised
                    // deeplink. Mirrors Android's intent-filter set in
                    // AndroidManifest.xml lines 98-126.
                    Task { @MainActor in
                        WoofWalkApp.handleDeeplink(url: url)
                    }
                }
                .task {
                    await NotificationService.shared.requestPermission()
                }
                .task {
                    await screenshotAutomation.runAutomation()
                }
        }
    }

    /// Pure router for `woofwalk://...` URLs. Exposed `static` so the
    /// scheme registration test (when it lands) can exercise the same
    /// logic without spinning up the App scene.
    @MainActor
    static func handleDeeplink(url: URL) {
        guard url.scheme?.lowercased() == "woofwalk" else { return }
        let host = url.host?.lowercased() ?? ""
        let pathSegments = url.pathComponents.filter { $0 != "/" }
        let nav = AppNavigator.shared

        // Only the Map tab's NavigationStack has the
        // `.navigationDestination(for: AppRoute.self)` modifier — the
        // other tabs' stacks are detail-only. Force-switch to map so
        // any AppRoute we push lands on a stack that can resolve it.
        nav.switchTab(.map)

        switch host {
        case "walk":
            // woofwalk://walk/{walkSessionId} — post-walk recap deeplink
            // from the portal. Routes to the live-share screen which
            // doubles as the recap view for completed walks.
            if let walkId = pathSegments.first, !walkId.isEmpty {
                nav.popToRoot()
                nav.navigate(to: .liveShare(walkId: walkId))
            }
        case "accept-invite":
            // woofwalk://accept-invite?token=<invitationId>
            // We support both ?token= and ?invitationId= for
            // forward-compat with the portal's older email format.
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let token = comps?.queryItems?.first(where: { $0.name == "token" })?.value
                ?? comps?.queryItems?.first(where: { $0.name == "invitationId" })?.value
                ?? ""
            if !token.isEmpty {
                nav.popToRoot()
                nav.navigate(to: .acceptInvite(token: token))
            }
        default:
            // Silently no-op on unknown hosts (e.g. Android-only ones
            // like booking, chat, payment that we haven't ported yet).
            // Crashing here would leave any cold-start deeplink dead.
            break
        }
    }

    /// Pulled out of `body` because the 5-branch if/else chain was
    /// hitting SwiftUI's ViewBuilder type-inference ceiling and
    /// throwing "no exact matches in reference to static method
    /// 'buildExpression'". Using AnyView short-circuits the
    /// type-inference work — the runtime cost is negligible since
    /// this only fires on auth-state transitions.
    private var rootView: AnyView {
        if isTestMode {
            // CI/test mode: skip onboarding and auth, go straight to app.
            return AnyView(MainTabView())
        }
        if !hasCompletedOnboarding {
            return AnyView(OnboardingView(onComplete: {
                hasCompletedOnboarding = true
            }))
        }
        if authViewModel.authState == .authenticated && authViewModel.needsProfileSetup {
            return AnyView(NavigationView {
                ProfileSetupView(
                    viewModel: authViewModel,
                    onComplete: {
                        authViewModel.needsProfileSetup = false
                    }
                )
            })
        }
        if authViewModel.authState == .authenticated {
            return AnyView(MainTabView())
        }
        return AnyView(AuthRootView(authViewModel: authViewModel))
    }
}

/// Auth flow: login / signup / forgot password
struct AuthRootView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showSignup = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationView {
            if authViewModel.authState == .loading {
                ProgressView("Signing in...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showSignup {
                SignupView(
                    viewModel: authViewModel,
                    onNavigateToLogin: { showSignup = false },
                    onSignupSuccess: { }
                )
            } else if showForgotPassword {
                ForgotPasswordView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Back") { showForgotPassword = false }
                        }
                    }
            } else {
                LoginView(
                    viewModel: authViewModel,
                    onNavigateToSignup: { showSignup = true },
                    onNavigateToForgotPassword: { showForgotPassword = true },
                    onLoginSuccess: { }
                )
            }
        }
    }
}
