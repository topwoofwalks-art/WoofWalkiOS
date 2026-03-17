import SwiftUI

struct MainTabView: View {
    @StateObject private var navigator = AppNavigator.shared
    @StateObject private var badgeService = BadgeAwardingService.shared
    @StateObject private var walkTracking = WalkTrackingService.shared
    @StateObject private var updateChecker = AppUpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            if updateChecker.updateAvailable {
                AppUpdateBanner(
                    currentVersion: updateChecker.currentVersion,
                    latestVersion: updateChecker.latestVersion,
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
                    onTap: { navigator.selectedTab = .map }
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
        } // TabView
        .task {
            await updateChecker.checkForUpdate()
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
