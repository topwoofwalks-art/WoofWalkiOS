import SwiftUI
import Firebase
import FirebaseAppCheck
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

    /// Pending recovery snapshot detected on cold-launch. Surfaced as a
    /// non-blocking overlay sheet after the first scene appears so the
    /// user can resume / discard an in-flight walk that the OS killed
    /// before stopTracking() could fire. Set in `init()` BEFORE the
    /// scene mounts, consumed by `.sheet(item:)` on the root view.
    /// Mirrors Android's `WalkBootReceiver` cold-resume flow.
    @State private var pendingInflightWalk: WalkTrackingService.InflightWalkSnapshot?

    init() {
        // Firebase App Check — issues attestation tokens that the backend
        // (Firestore/Functions/Storage rules) enforces alongside Auth. Must
        // run BEFORE `FirebaseApp.configure()` so the first SDK init picks
        // up the provider. DEBUG builds use the debug provider (token
        // surfaces in Xcode console, must be allow-listed in the Firebase
        // console) so simulator + dev builds aren't rejected. Release
        // builds use AppAttest on iOS 14+ with a DeviceCheck fallback —
        // see WoofWalkAppCheckProviderFactory. Mirrors Android's
        // `PlayIntegrityAppCheckProviderFactory` wiring in
        // WoofWalkApplication.kt.
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        let providerFactory = WoofWalkAppCheckProviderFactory()
        #endif
        AppCheck.setAppCheckProviderFactory(providerFactory)

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

        // Backgrounded-crash recovery — check for an in-flight walk
        // marker left over from a previous launch that was killed
        // before stopTracking() could fire. If present and started
        // within the last 6 hours we'll surface a non-blocking
        // "Resume previous walk?" sheet once the root scene appears.
        // Mirrors Android's `WalkBootReceiver` cold-resume flow.
        if WalkTrackingService.hasRecoverableInflightWalk() {
            _pendingInflightWalk = State(initialValue: WalkTrackingService.readInflightWalk())
        }
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
                // Backgrounded-crash recovery sheet. Driven by the
                // `pendingInflightWalk` snapshot captured in init().
                // Non-blocking — appears as an overlay AFTER the first
                // scene mounts so a user with no in-flight walk sees
                // zero added launch latency. Mirrors Android's
                // `WalkBootReceiver` resume flow.
                .sheet(item: $pendingInflightWalk) { inflight in
                    InflightWalkRecoverySheet(
                        inflight: inflight,
                        onResume: {
                            WalkTrackingService.shared.resumeWalk(walkId: inflight.walkId)
                            pendingInflightWalk = nil
                        },
                        onDiscard: {
                            WalkTrackingService.finaliseOrphanedWalk(inflight)
                            pendingInflightWalk = nil
                        }
                    )
                }
        }
    }

    /// Pure router for `woofwalk://...` custom-scheme URLs AND
    /// `https://woofwalk.app/...` Universal Links. Exposed `static` so
    /// the scheme registration test (when it lands) can exercise the
    /// same logic without spinning up the App scene.
    ///
    /// Source-of-truth parity: `MainActivity.parseWoofWalkScheme`
    /// (Android) routes the same set of hosts onto the same destinations.
    /// Adding a host here REQUIRES the matching Android branch and an
    /// equivalent `AppRoute` enum case in `Navigation/Route.swift`.
    @MainActor
    static func handleDeeplink(url: URL) {
        // Normalise both custom-scheme and Universal-Link URLs into a
        // (host, pathSegments, query) triple. For universal links the
        // host is the FIRST path segment (e.g. `https://woofwalk.app/walk/xyz`
        // → host = "walk", remaining = ["xyz"]). Mirrors Android's
        // `parseDeepLinkUri` which does the same split.
        let scheme = url.scheme?.lowercased() ?? ""
        var host = (url.host?.lowercased() ?? "")
        var pathSegments = url.pathComponents.filter { $0 != "/" }

        if scheme == "https" || scheme == "http" {
            guard host == "woofwalk.app" else { return }
            host = (pathSegments.first ?? "").lowercased()
            if !pathSegments.isEmpty { pathSegments = Array(pathSegments.dropFirst()) }
        } else if scheme != "woofwalk" {
            return
        }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query: (String) -> String? = { name in
            comps?.queryItems?.first(where: { $0.name == name })?.value
        }
        // First path segment (after host) — the common "{id}" parameter.
        let firstId = pathSegments.first.flatMap { $0.isEmpty ? nil : $0 }
        let nav = AppNavigator.shared

        // Only the Map tab's NavigationStack has the
        // `.navigationDestination(for: AppRoute.self)` modifier — the
        // other tabs' stacks are detail-only. Force-switch to map so
        // any AppRoute we push lands on a stack that can resolve it.
        nav.switchTab(.map)

        // Normalise host aliases: Android manifest uses snake_case
        // (live_tracking, walk_report, add_tip, team_invite,
        // stripe_connect, friend-invite). We accept both snake- and
        // kebab-case so links typed by humans or generated by old
        // versions still route.
        let normalisedHost: String = {
            switch host {
            case "live-tracking", "live_tracking": return "live-tracking"
            case "walk-report", "walk_report": return "walk-report"
            case "add-tip", "add_tip": return "add-tip"
            case "team-invite", "team_invite": return "team-invite"
            case "stripe-connect", "stripe_connect": return "stripe-connect"
            case "watch-walk", "watch_walk", "watch": return "watch-walk"
            case "lost-dog", "lost_dog": return "lost-dog"
            case "qa": return "q"   // FAQ alias
            default: return host
            }
        }()

        switch normalisedHost {
        case "walk":
            // woofwalk://walk/{walkId} — shared-walk story / recap.
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .liveShare(walkId: id))
            }
        case "booking":
            // woofwalk://book/{bookingId} or woofwalk://booking/{bookingId}
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .clientBookingDetail(bookingId: id))
            } else {
                nav.popToRoot()
                nav.navigate(to: .clientBookings)
            }
        case "book":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .clientBookingDetail(bookingId: id))
            }
        case "live-tracking":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .liveShare(walkId: id))
            }
        case "walk-report":
            nav.popToRoot()
            nav.navigate(to: .walkHistory)
        case "chat":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .chatDetail(chatId: id))
            } else {
                nav.popToRoot()
                nav.navigate(to: .chatList)
            }
        case "post":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .postDetail(postId: id))
            } else {
                nav.popToRoot()
                nav.navigate(to: .feed)
            }
        case "profile":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .publicProfile(userId: id))
            } else {
                nav.popToRoot()
                nav.navigate(to: .profile)
            }
        case "friend-invite", "add", "invite":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .friendInvite(userId: id))
                // Also push the public-profile view so the recipient can
                // tap "Add Friend" — same flow as Android.
                nav.navigate(to: .publicProfile(userId: id))
            }
        case "event":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .eventDetail(eventId: id))
            }
        case "challenge":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .challengeDetail(challengeId: id))
            } else {
                nav.popToRoot()
                nav.navigate(to: .challenges)
            }
        case "payment":
            let id = query("bookingId") ?? firstId
            if let id {
                nav.popToRoot()
                nav.navigate(to: .clientBookingDetail(bookingId: id))
            }
        case "add-tip":
            let id = query("bookingId") ?? firstId
            if let id {
                nav.popToRoot()
                nav.navigate(to: .clientBookingDetail(bookingId: id))
            }
        case "earnings":
            nav.popToRoot()
            nav.navigate(to: .businessEarnings)
        case "review":
            let id = query("bookingId") ?? firstId
            if let id {
                nav.popToRoot()
                nav.navigate(to: .clientBookingDetail(bookingId: id))
            }
        case "team-invite":
            // Android maps team_invite/{orgId} to BusinessSignup with
            // orgId — iOS doesn't have a BusinessSignup AppRoute yet,
            // so route to acceptInvite which is the closest existing
            // surface for org-membership invites.
            let token = query("token")
                ?? query("invitationId")
                ?? query("orgId")
                ?? firstId
                ?? ""
            if !token.isEmpty {
                nav.popToRoot()
                nav.navigate(to: .acceptInvite(token: token))
            }
        case "home":
            nav.popToRoot()
            // Map is already the default tab + root.
        case "stripe-connect", "oauth":
            // OAuth callbacks are handled by the Stripe SDK + Branch
            // SDK pre-empting the URL; if we ever fall through to here
            // the user just lands on the business dashboard.
            nav.popToRoot()
            nav.navigate(to: .businessDashboard)
        case "accept-invite":
            // woofwalk://accept-invite?token=<invitationId>
            // We support both ?token= and ?invitationId= for
            // forward-compat with the portal's older email format,
            // and ALSO fall through to a path token (Android parity).
            let token = query("token")
                ?? query("invitationId")
                ?? firstId
                ?? ""
            if !token.isEmpty {
                nav.popToRoot()
                nav.navigate(to: .acceptInvite(token: token))
            }
        case "lost-dog":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .lostDog(alertId: id))
            }
        case "watch-walk":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .watchWalk(token: id))
            }
        case "dog":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .dogStats(dogId: id))
            }
        case "provider":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .providerDetail(providerId: id))
            }
        case "charity":
            nav.popToRoot()
            nav.navigate(to: .charitySettings)
        case "settings":
            // woofwalk://settings/{section} — sections we recognise map
            // to dedicated routes; anything else lands on the root
            // settings hub.
            switch firstId ?? "" {
            case "language":      nav.popToRoot(); nav.navigate(to: .languageSettings)
            case "notifications": nav.popToRoot(); nav.navigate(to: .notificationSettings)
            case "privacy":       nav.popToRoot(); nav.navigate(to: .privacySettings)
            case "auto-reply":    nav.popToRoot(); nav.navigate(to: .autoReplySettings)
            case "charity":       nav.popToRoot(); nav.navigate(to: .charitySettings)
            default:              nav.popToRoot(); nav.navigate(to: .settings)
            }
        case "referral":
            // No dedicated referral landing on iOS — Branch handles the
            // attribution side-channel. Drop the user onto the settings
            // root where they can see their own referral code.
            nav.popToRoot()
            nav.navigate(to: .settings)
        case "community":
            // woofwalk://community/{id} OR /community/{id}/post/{postId}
            if let id = firstId {
                // Path tail: ["{communityId}", "post", "{postId}"]
                if pathSegments.count >= 3, pathSegments[1].lowercased() == "post" {
                    let postId = pathSegments[2]
                    nav.popToRoot()
                    nav.navigate(to: .communityPost(communityId: id, postId: postId))
                } else {
                    nav.popToRoot()
                    nav.navigate(to: .communityDetail(communityId: id))
                }
            }
        case "q":
            if let id = firstId {
                nav.popToRoot()
                nav.navigate(to: .question(questionId: id))
            }
        case "share":
            if let token = firstId {
                nav.popToRoot()
                nav.navigate(to: .share(shareToken: token))
            }
        case "cash-request":
            // FCM-driven host. Path is /<role>/<requestId>.
            if pathSegments.count >= 2 {
                let role = pathSegments[0].lowercased()
                let requestId = pathSegments[1]
                nav.popToRoot()
                if role == "business" {
                    nav.navigate(to: .businessCashRequest(requestId: requestId))
                } else {
                    nav.navigate(to: .clientCashRequest(requestId: requestId))
                }
            }
        default:
            // Silently no-op on unknown hosts. Logged so we can spot
            // missing branches via Console.app when triaging links.
            print("[Deeplink] Unhandled host: \(host) (scheme: \(scheme))")
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

/// Cold-launch sheet for recovering an in-flight walk that the OS
/// killed before stopTracking() could fire. Mirrors Android's
/// `WalkBootReceiver` resume prompt.
struct InflightWalkRecoverySheet: View {
    let inflight: WalkTrackingService.InflightWalkSnapshot
    let onResume: () -> Void
    let onDiscard: () -> Void

    private var elapsedDescription: String {
        let elapsed = Date().timeIntervalSince(inflight.startedAt)
        let mins = Int(elapsed / 60)
        if mins < 60 { return "\(mins) min ago" }
        let hours = mins / 60
        let rem = mins % 60
        return "\(hours)h \(rem)m ago"
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "figure.walk")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.accentColor)
                .padding(.top, 32)

            Text("Resume previous walk?")
                .font(.title2.weight(.semibold))

            VStack(spacing: 4) {
                Text("It looks like a walk was interrupted.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Text("Started \(elapsedDescription)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if !inflight.dogIds.isEmpty {
                    Text("\(inflight.dogIds.count) dog\(inflight.dogIds.count == 1 ? "" : "s") tagged")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 16)

            VStack(spacing: 12) {
                Button(action: onResume) {
                    Text("Resume walk")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: onDiscard) {
                    Text("Discard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
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
