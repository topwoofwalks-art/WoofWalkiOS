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
            LiveShareView(walkId: walkId, onStopSharing: {})
        case .walkPhotoGallery(let walkId):
            PlaceholderView(title: "Walk Photos", icon: "photo.on.rectangle.angled", detail: walkId, description: "Browse and share photos captured during your walk")
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
            CreatePostSheet(onPost: { _, _ in })
                .navigationTitle("Create Story")
        case .storyViewer(let userId):
            PlaceholderView(title: "Story Viewer", icon: "eye.fill", detail: userId, description: "Watch stories shared by other walkers in your community")
        case .publicProfile(let userId):
            PlaceholderView(title: "Public Profile", icon: "person.crop.circle", detail: userId, description: "View walker profile, dogs, and walk history")
        case .followList(let userId, let type):
            PlaceholderView(title: "\(type.capitalized)", icon: "person.2.fill", detail: userId, description: "Browse \(type) list and discover new walkers")
        case .reportPost(let postId):
            PlaceholderView(title: "Report Post", icon: "exclamationmark.triangle.fill", detail: postId, description: "Flag inappropriate content for community moderators")
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
            PlaceholderView(title: "Badge Detail", icon: "trophy.circle.fill", detail: badgeId, description: "View badge requirements, progress, and how to earn it")
        case .walkHistoryDetail(let walkId):
            WalkHistoryDetailScreen(walkId: walkId)
        case .milestones:
            MilestonesListScreen()
        case .levelUp:
            PlaceholderView(title: "Level Up", icon: "arrow.up.circle.fill", description: "See your level progress and upcoming rewards")
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
            PlaceholderView(title: "Business Dashboard", icon: "chart.bar.fill", description: "Overview of bookings, earnings, and client activity")
        case .businessSchedule:
            PlaceholderView(title: "Business Schedule", icon: "calendar", description: "View and manage your upcoming walk bookings")
        case .businessClients:
            PlaceholderView(title: "Business Clients", icon: "person.2.fill", description: "Manage your client list and dog profiles")
        case .businessEarnings:
            PlaceholderView(title: "Business Earnings", icon: "sterlingsign.circle.fill", description: "Track revenue, invoices, and payment history")
        case .businessSettings:
            PlaceholderView(title: "Business Settings", icon: "gearshape.fill", description: "Configure service areas, pricing, and availability")

        // Client
        case .clientBookings:
            PlaceholderView(title: "My Bookings", icon: "calendar.badge.clock", description: "View upcoming and past walk bookings")
        case .clientDashboard:
            PlaceholderView(title: "Client Dashboard", icon: "house.fill", description: "Your dog walking overview and quick actions")
        case .clientInvoices:
            PlaceholderView(title: "Invoices", icon: "doc.text.fill", description: "View and pay outstanding invoices")
        case .clientMessages:
            PlaceholderView(title: "Messages", icon: "bubble.left.and.bubble.right.fill", description: "Chat with your dog walker")

        // Map features
        case .hazardReport:
            HazardReportScreen()
        case .hazardDetail(let hazardId):
            PlaceholderView(title: "Hazard Detail", icon: "exclamationmark.triangle", detail: hazardId, description: "View hazard details, severity, and community reports")
        case .trailConditionReport:
            TrailConditionSheet(userLocation: nil, onSubmit: { _, _, _ in })
        case .offLeadZones:
            OffLeadZonesScreen()
        case .rainModeSettings:
            RainModeSettingsView()
        case .routeLibrary:
            RouteLibraryScreen()
        case .routeDetail(let routeId):
            RouteDetailScreen(routeId: routeId)
        case .nearbyPubs:
            NearbyPubsSheetWrapper()
        case .pubDetail(let pubId):
            PlaceholderView(title: "Pub Detail", icon: "mug.fill", detail: pubId, description: "View pub amenities, dog policy, photos, and directions")

        // Settings
        case .languageSettings:
            LanguageSelectionView()
        case .autoReplySettings:
            AwayModeSettingsWrapper()
        case .notificationSettings:
            PlaceholderView(title: "Notifications", icon: "bell.fill", description: "Configure push notifications, hazard alerts, and reminders")
        case .privacySettings:
            PlaceholderView(title: "Privacy", icon: "lock.shield.fill", description: "Manage profile visibility, location sharing, and data preferences")
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
    var description: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title.bold())
            if let description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }
            Label("Coming soon", systemImage: "clock")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle(title)
    }
}
