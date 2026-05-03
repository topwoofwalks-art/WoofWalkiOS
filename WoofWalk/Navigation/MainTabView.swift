import SwiftUI

struct MainTabView: View {
    @StateObject private var navigator = AppNavigator.shared
    @StateObject private var badgeService = BadgeAwardingService.shared
    @StateObject private var walkTracking = WalkTrackingService.shared
    @StateObject private var motionService = MotionActivityService.shared
    @StateObject private var updateChecker = AppUpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
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
                    Label(AppTab.map.rawValue, systemImage: AppTab.map.icon)
                }
                .tag(AppTab.map)

                NavigationStack {
                    FeedScreen()
                }
                .tabItem {
                    Label(AppTab.feed.rawValue, systemImage: AppTab.feed.icon)
                }
                .tag(AppTab.feed)

                NavigationStack {
                    SocialHubScreen()
                }
                .tabItem {
                    Label(AppTab.social.rawValue, systemImage: AppTab.social.icon)
                }
                .tag(AppTab.social)

                NavigationStack {
                    DiscoveryScreen()
                }
                .tabItem {
                    Label(AppTab.discover.rawValue, systemImage: AppTab.discover.icon)
                }
                .tag(AppTab.discover)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label(AppTab.profile.rawValue, systemImage: AppTab.profile.icon)
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
