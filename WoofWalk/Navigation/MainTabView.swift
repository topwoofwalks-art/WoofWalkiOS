import SwiftUI

struct MainTabView: View {
    @StateObject private var navigator = AppNavigator.shared
    @StateObject private var badgeService = BadgeAwardingService.shared
    @StateObject private var walkTracking = WalkTrackingService.shared
    @StateObject private var motionService = MotionActivityService.shared
    @StateObject private var updateChecker = AppUpdateChecker.shared

    @State private var lostDogAlertPayload: [AnyHashable: Any]?
    @State private var showLostDogAlert = false

    // Safety-critical: full-screen panic-alarm takeover for guardians.
    // Driven by `.panicAlertReceived` (NotificationService routes
    // FCM `type: "panicAlert"` here). Mirrors Android's
    // `PanicAlarmActivity` full-screen intent.
    @State private var panicAlertPayload: [AnyHashable: Any]?
    @State private var showPanicAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Yellow "verify your email" banner — parity with Android's
            // MainTabView top-of-tab prompt. Renders nothing when verified
            // or signed-out; auto-refreshes on app foreground.
            EmailVerificationBanner()

            if updateChecker.updateAvailable {
                AppUpdateBanner(
                    currentVersion: updateChecker.currentVersion,
                    latestVersion: updateChecker.latestVersion ?? updateChecker.currentVersion,
                    onUpdate: {
                        if let url = URL(string: "https://apps.apple.com/app/woofwalk/idXXXXXXXXX") {
                            UIApplication.shared.open(url)
                        }
                    },
                    onDismiss: { updateChecker.updateAvailable = false }
                )
            }

            if walkTracking.trackingState.isTracking && navigator.selectedTab != .map {
                ActiveWalkBanner(
                    distance: walkTracking.trackingState.distanceMeters,
                    duration: TimeInterval(walkTracking.trackingState.durationSeconds),
                    isPaused: walkTracking.trackingState.isPaused,
                    onTap: { navigator.selectedTab = .map },
                    humanSteps: motionService.motionAuthorisationStatus == .authorized
                        ? motionService.stepCount
                        : nil
                )
            }

            TabView(selection: $navigator.selectedTab) {
                NavigationStack(path: $navigator.path) {
                    MapScreen()
                        .navigationDestination(for: AppRoute.self) { route in
                            RouteDestination(route: route)
                        }
                }
                .tabItem {
                    Label(String(localized: "tab_map"), systemImage: AppTab.map.icon)
                }
                .tag(AppTab.map)

                NavigationStack {
                    FeedScreen()
                }
                .tabItem {
                    Label(String(localized: "tab_feed"), systemImage: AppTab.feed.icon)
                }
                .tag(AppTab.feed)

                NavigationStack {
                    SocialHubScreen()
                }
                .tabItem {
                    Label(String(localized: "tab_social"), systemImage: AppTab.social.icon)
                }
                .tag(AppTab.social)

                NavigationStack {
                    DiscoveryScreen()
                }
                .tabItem {
                    Label(String(localized: "tab_discover"), systemImage: AppTab.discover.icon)
                }
                .tag(AppTab.discover)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label(String(localized: "tab_profile"), systemImage: AppTab.profile.icon)
                }
                .tag(AppTab.profile)
            }

            // Ad banner area (matches Android bottom ad)
            AdBannerPlaceholder()
        }
        .task {
            await updateChecker.checkForUpdate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkRouteRequested)) { note in
            // FCM-driven (and in-app cash-shortage sheet) deep-link entry.
            // Currently we only need to push the route onto the active
            // navigator path; tab selection stays untouched (the route
            // resolves the same destination regardless of source tab).
            if let route = note.userInfo?["route"] as? AppRoute {
                navigator.navigate(to: route)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lostDogAlertReceived)) { note in
            guard let payload = note.userInfo, !payload.isEmpty else { return }
            lostDogAlertPayload = payload
            showLostDogAlert = true
        }
        .sheet(isPresented: $showLostDogAlert) {
            if let payload = lostDogAlertPayload {
                LostDogAlertSheet(payload: payload) {
                    showLostDogAlert = false
                    lostDogAlertPayload = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .panicAlertReceived)) { note in
            // Safety-critical: a walker triggered the panic button. Open
            // the full-screen alarm cover immediately — siren + map + the
            // three forced-choice actions live inside `PanicAlarmSheet`.
            guard let payload = note.userInfo, !payload.isEmpty else { return }
            panicAlertPayload = payload
            showPanicAlert = true
        }
        .fullScreenCover(isPresented: $showPanicAlert) {
            if let payload = panicAlertPayload {
                PanicAlarmSheet(payload: payload) {
                    showPanicAlert = false
                    panicAlertPayload = nil
                }
            }
        }
        .tint(.turquoise60)
        .overlay {
            if let achievement = badgeService.pendingAchievements.first {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                AchievementRevealCard(
                    achievement: achievement,
                    onDismiss: { badgeService.dismissNextAchievement() }
                )
            }
        }
    }
}
