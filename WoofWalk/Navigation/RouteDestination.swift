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
            WalkPhotoGalleryScreen(walkId: walkId)
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
        case .globalSearch:
            GlobalSearchScreen()
        case .postDetail(let postId):
            PostDetailScreen(post: Post(id: postId))
        case .createPost:
            CreatePostSheet(onPost: { _, _ in })
        case .createStory:
            CreatePostSheet(onPost: { _, _ in })
                .navigationTitle("Create Story")
        case .storyViewer(let userId):
            StoryViewerScreen(userId: userId)
        case .publicProfile(let userId):
            PublicProfileScreen(userId: userId)
        case .followList(let userId, let type):
            FollowListScreen(userId: userId, type: type)
        case .reportPost(let postId):
            ReportPostSheet(postId: postId)
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
            BadgeDetailSheet(badgeId: badgeId)
        case .walkHistoryDetail(let walkId):
            WalkHistoryDetailScreen(walkId: walkId)
        case .milestones:
            MilestonesListScreen()
        case .levelUp:
            LevelUpScreen()
        case .discovery:
            DiscoveryScreen()
        case .providerDetail(let providerId):
            ProviderDetailScreen(providerId: providerId)
        case .meetGreetRequest(let orgId):
            MeetGreetRequestScreen(providerOrgId: orgId)
        case .meetGreetThread(let threadId):
            MeetGreetThreadScreen(threadId: threadId)
        case .meetGreetClientInbox:
            MeetGreetInboxScreen(perspective: .client)
        case .meetGreetProviderInbox:
            MeetGreetInboxScreen(perspective: .provider)
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
            BusinessDashboardScreen()
        case .businessSchedule:
            BusinessScheduleScreen(viewModel: BusinessViewModel())
        case .businessClients:
            BusinessClientsScreen(viewModel: BusinessViewModel())
        case .businessClientDetail(let clientId):
            ClientDetailScreen(clientId: clientId)
        case .businessEarnings:
            BusinessEarningsScreen()
        case .businessSettings:
            BusinessSettingsScreen()
        case .businessWalkConsole(let bookingId):
            BusinessWalkConsoleScreen(bookingId: bookingId)
        case .businessWalkConsoleFull(let bookingId, let dogIds, let bookingIds):
            BusinessWalkConsoleScreen(bookingId: bookingId, dogIds: dogIds, bookingIds: bookingIds)
        case .businessTodaysWalks:
            BusinessTodaysWalksScreen(viewModel: BusinessViewModel())
        case .scanKey:
            ScanKeyScreen()

        // Client
        case .clientBookings:
            ClientBookingsScreen()
        case .clientBookingDetail(let bookingId):
            BookingDetailScreen(bookingId: bookingId)
        case .clientDashboard:
            ClientDashboardScreen()
        case .clientInvoices:
            ClientInvoicesScreen()
        case .clientMessages:
            ClientMessagesScreen()
        case .providerSearch(let serviceType):
            ProviderSearchView(serviceType: serviceTypeFromString(serviceType))
        case .booking(let providerId):
            BookingFlowScreen(preselectedProviderId: providerId)

        // Live service screens
        case .groomingLive(let sessionId):
            GroomingLiveScreen(sessionId: sessionId)
        case .careLive(let sessionId, let serviceType):
            CareLiveScreen(
                sessionId: sessionId,
                serviceType: CareServiceType(rawValue: serviceType) ?? .sitting
            )
        case .daycareLive(let sessionId):
            DaycareLiveScreen(sessionId: sessionId)
        case .trainingLive(let sessionId):
            TrainingLiveScreen(sessionId: sessionId)
        case .daycareConsole(let bookingId, let dogIds):
            DaycareConsoleScreen(sessionId: bookingId, bookingId: bookingId, dogIds: dogIds)
        case .trainingSession(let sessionId):
            TrainingSessionScreen(sessionId: sessionId)

        // Map features
        case .hazardReport:
            HazardReportScreen()
        case .hazardDetail(let hazardId):
            HazardDetailScreen(hazardId: hazardId)
        case .trailConditionReport:
            TrailConditionSheet(userLocation: nil, onSubmit: { _, _, _ in })
        case .offLeadZones:
            OffLeadZonesScreen()
        case .rainModeSettings:
            RainModeSettingsView()
        case .plannedWalks:
            PlannedWalksScreen()
        case .routeLibrary:
            RouteLibraryScreen()
        case .routeDetail(let routeId):
            RouteDetailScreen(routeId: routeId)
        case .nearbyPubs:
            NearbyPubsSheetWrapper()
        case .pubDetail(let pubId):
            PubDetailScreen(pubId: pubId)

        // Settings
        case .languageSettings:
            LanguageSelectionView()
        case .autoReplySettings:
            AwayModeSettingsWrapper()
        case .notificationSettings:
            NotificationSettingsScreen()
        case .privacySettings:
            PrivacySettingsScreen()

        // Cash-shortage notify flow
        case .clientCashRequest(let requestId):
            CashTopupRequestView(requestId: requestId)
        case .businessCashRequest(let requestId):
            CashTopupReplyView(requestId: requestId)

        // Team invitation deeplink
        case .acceptInvite(let token):
            AcceptInviteScreen(token: token)

        // Deep-link parity with Android — most reuse existing destinations.
        case .lostDog(let alertId):
            LostDogDetailScreen(alertId: alertId)
        case .watchWalk(let token):
            WatchWalkReceiverScreen(token: token)
        case .payment(let bookingId):
            BookingDetailScreen(bookingId: bookingId)
        case .addTip(let bookingId):
            BookingDetailScreen(bookingId: bookingId)
        case .review(let bookingId):
            BookingDetailScreen(bookingId: bookingId)
        case .teamInvite(let orgId):
            AcceptInviteScreen(token: orgId)
        case .friendInvite(let userId):
            PublicProfileScreen(userId: userId)
        case .stripeConnect:
            PlaceholderView(title: "Stripe Connect", icon: "creditcard")
        case .oauthCallback:
            PlaceholderView(title: "Signing in…", icon: "lock.shield")
        case .communityDetail:
            PlaceholderView(title: "Community", icon: "person.3")
        case .communityPost:
            PlaceholderView(title: "Community post", icon: "bubble.left.and.bubble.right")
        case .question:
            PlaceholderView(title: "Question", icon: "questionmark.circle")
        case .eventDetail:
            PlaceholderView(title: "Event", icon: "calendar")
        case .challengeDeepLink(let challengeId):
            ChallengeDetailScreen(challengeId: challengeId)
        case .dogDeepLink(let dogId):
            DogStatsDetailView(dogId: dogId, dogName: "")
        case .share:
            PlaceholderView(title: "Shared walk", icon: "square.and.arrow.up")
        case .providerDeepLink(let providerId):
            ProviderDetailScreen(providerId: providerId)
        case .charityDeepLink:
            CharitySettingsView()
        case .settingsSection:
            SettingsView()
        case .referral:
            PlaceholderView(title: "Referral", icon: "gift")
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
    @State private var holidayMode = HolidayMode()
    @State private var quickReplies = QuickReplyTemplate.defaults

    var body: some View {
        AwayModeSettingsView(
            isEnabled: $isEnabled,
            autoReplyMessage: $autoReplyMessage,
            startDate: $startDate,
            endDate: $endDate,
            holidayMode: $holidayMode,
            quickReplies: $quickReplies,
            onSave: {}
        )
        .navigationTitle("Auto-Reply")
    }
}

// MARK: - Placeholder for routes without destination views yet

/// Maps a service type string back to the ServiceType enum for provider search navigation.
private func serviceTypeFromString(_ value: String) -> ServiceType {
    ServiceType.allCases.first(where: { $0.rawValue == value }) ?? .dailyWalks
}

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
