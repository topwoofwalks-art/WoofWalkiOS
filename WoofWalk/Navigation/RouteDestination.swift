import SwiftUI
import CoreLocation
import MapKit

struct RouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .map:
            MapScreen()
        case .profile:
            ProfileView()
        case .settings:
            SettingsView()
        case .walkHistory:
            WalkHistoryScreen()
        case .stats:
            ProfileStatsView()
        case .editProfile:
            EditProfileView(viewModel: ProfileViewModel())
        case .leaderboard:
            LeaderboardView()
        case .walkCompletion(let distance, let duration):
            WalkCompletionScreen(
                distance: distance, duration: duration, pace: 0, steps: 0,
                dogNames: [], pointsEarned: 0, personalBest: nil,
                streakDays: 0, milestones: [], mapImage: nil,
                onShare: {}, onDone: {}
            )
        case .walkDetail(let walkId):
            WalkHistoryDetailScreen(walkId: walkId)
        case .liveShare(let walkId):
            PlaceholderView(title: "Live Share", icon: "location.fill", detail: walkId)
        case .walkPhotoGallery(let walkId):
            PlaceholderView(title: "Walk Photos", icon: "photo.on.rectangle.angled", detail: walkId)
        case .dogStats(let dogId):
            DogStatsDetailView(dogId: dogId, dogName: "")
        case .addDog:
            UnifiedDogFormView(onSave: { _ in })
        case .editDog:
            UnifiedDogFormView(onSave: { _ in })
        case .socialHub:
            SocialHubScreen()
        case .feed:
            FeedScreen()
        case .postDetail(let postId):
            PostDetailScreen(post: Post(id: postId))
        case .createPost:
            CreatePostSheet(onPost: { _, _ in })
        case .createStory:
            PlaceholderView(title: "Create Story", icon: "plus.circle.fill")
        case .storyViewer(let userId):
            PlaceholderView(title: "Story Viewer", icon: "eye.fill", detail: userId)
        case .publicProfile(let userId):
            PlaceholderView(title: "Public Profile", icon: "person.crop.circle", detail: userId)
        case .followList(let userId, let type):
            PlaceholderView(title: "\(type.capitalized)", icon: "person.2.fill", detail: userId)
        case .reportPost(let postId):
            PlaceholderView(title: "Report Post", icon: "exclamationmark.triangle.fill", detail: postId)
        case .challenges:
            ChallengesScreen()
        case .challengeDetail(let challengeId):
            ChallengeDetailScreen(challengeId: challengeId)
        case .league:
            LeagueView()
        case .streaks:
            ScrollView {
                VStack(spacing: 20) {
                    StreakBanner(streak: WalkStreak())
                        .padding()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Streak Milestones")
                            .font(.headline)
                        ForEach(WalkStreak.milestoneDays, id: \.self) { day in
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text("\(day) Days")
                                Spacer()
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Streaks")
        case .badgeGallery:
            BadgeGalleryScreen()
        case .badgeDetail(let badgeId):
            PlaceholderView(title: "Badge Detail", icon: "trophy.circle.fill", detail: badgeId)
        case .walkHistoryDetail(let walkId):
            WalkHistoryDetailScreen(walkId: walkId)
        case .milestones:
            PlaceholderView(title: "Milestones", icon: "star.fill")
        case .levelUp:
            PlaceholderView(title: "Level Up", icon: "arrow.up.circle.fill")
        case .discovery:
            DiscoveryScreen()
        case .providerDetail(let providerId):
            ProviderDetailScreen(providerId: providerId)
        case .notifications:
            NotificationCenterScreen()
        case .charitySettings:
            CharitySettingsView()
        case .chatList:
            ChatListScreen()
        case .chatDetail(let chatId):
            ChatDetailScreen(chatId: chatId)

        // Business
        case .businessInbox:
            BusinessInboxScreen()
        case .businessDashboard:
            PlaceholderView(title: "Business Dashboard", icon: "chart.bar.fill")
        case .businessSchedule:
            PlaceholderView(title: "Business Schedule", icon: "calendar")
        case .businessClients:
            PlaceholderView(title: "Business Clients", icon: "person.2.fill")
        case .businessEarnings:
            PlaceholderView(title: "Business Earnings", icon: "sterlingsign.circle.fill")
        case .businessSettings:
            PlaceholderView(title: "Business Settings", icon: "gearshape.fill")

        // Client
        case .clientBookings:
            PlaceholderView(title: "My Bookings", icon: "calendar.badge.clock")
        case .clientDashboard:
            PlaceholderView(title: "Client Dashboard", icon: "house.fill")
        case .clientInvoices:
            PlaceholderView(title: "Invoices", icon: "doc.text.fill")
        case .clientMessages:
            PlaceholderView(title: "Messages", icon: "bubble.left.and.bubble.right.fill")

        // Map features
        case .hazardReport:
            PlaceholderView(title: "Report Hazard", icon: "exclamationmark.triangle.fill")
        case .hazardDetail(let hazardId):
            PlaceholderView(title: "Hazard Detail", icon: "exclamationmark.triangle", detail: hazardId)
        case .trailConditionReport:
            PlaceholderView(title: "Trail Conditions", icon: "leaf.fill")
        case .offLeadZones:
            PlaceholderView(title: "Off-Lead Zones", icon: "pawprint.fill")
        case .rainModeSettings:
            RainModeSettingsView()
        case .routeLibrary:
            RouteLibraryScreen()
        case .routeDetail(let routeId):
            RouteDetailScreen(routeId: routeId)
        case .nearbyPubs:
            NearbyPubsSheetWrapper()
        case .pubDetail(let pubId):
            PlaceholderView(title: "Pub Detail", icon: "mug.fill", detail: pubId)

        // Settings
        case .languageSettings:
            LanguageSelectionView()
        case .autoReplySettings:
            AwayModeSettingsWrapper()
        case .notificationSettings:
            PlaceholderView(title: "Notifications", icon: "bell.fill")
        case .privacySettings:
            PlaceholderView(title: "Privacy", icon: "lock.shield.fill")
        }
    }
}

// MARK: - Wrapper views for screens requiring injected parameters

/// Standalone wrapper that provides NearbyPubsSheet with location-based pub data.
private struct NearbyPubsSheetWrapper: View {
    @StateObject private var locationManager = LocationManager()
    @State private var pubs: [POI] = []

    var body: some View {
        NearbyPubsSheet(
            pubs: pubs,
            userLocation: locationManager.location,
            onSelect: { _ in },
            onOpenInMaps: { pub in
                let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: pub.lat, longitude: pub.lng))
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = pub.title
                mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
            }
        )
    }
}

/// Standalone wrapper that manages state for AwayModeSettingsView bindings.
private struct AwayModeSettingsWrapper: View {
    @State private var isEnabled = false
    @State private var autoReplyMessage = "Thanks for your message! I'm currently away and will respond when I'm back."
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400)

    var body: some View {
        AwayModeSettingsView(
            isEnabled: $isEnabled,
            autoReplyMessage: $autoReplyMessage,
            startDate: $startDate,
            endDate: $endDate,
            onSave: {}
        )
        .navigationTitle("Auto-Reply")
    }
}

// MARK: - Placeholder for routes without destination views yet

struct PlaceholderView: View {
    let title: String
    let icon: String
    var detail: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title.bold())
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }
            Text("Coming soon")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle(title)
    }
}
