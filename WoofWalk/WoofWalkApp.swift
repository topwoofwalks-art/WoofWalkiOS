import SwiftUI
import Firebase
import FirebaseAuth
import StripePaymentSheet

@main
struct WoofWalkApp: App {
    @StateObject private var screenshotAutomation = ScreenshotAutomation.shared
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        } else {
            print("[WoofWalk] GoogleService-Info.plist not found - Firebase disabled")
        }

        // Stripe SDK — full PaymentSheet parity with Android. The publishable
        // key is hard-coded to match Android's `WoofWalkApplication.kt`
        // (the live key for the WoofWalk Stripe account). PaymentIntents
        // are created server-side by `processBookingPayment`; the
        // PaymentSheet client only needs the publishable key + clientSecret.
        StripeAPI.defaultPublishableKey = "pk_live_51Sg8grCHt9yHTLb1wpKwVN5LyUR93kgUYJmjxs5NrD4rHXGyFuAnyskiQYCRZKQNJVALvnnHeZol3Xv8gaIIF0aD00NoVlE74t"

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
