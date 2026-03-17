import SwiftUI

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
            WalkHistoryView()
        case .stats:
            StatsView()
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
            Text("Walk Detail — \(walkId)")
                .navigationTitle("Walk Detail")
        case .dogStats(let dogId):
            DogStatsScreen(dog: DogProfile(id: dogId, name: ""))
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
        case .challenges:
            ChallengesScreen()
        case .challengeDetail(let challengeId):
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Challenge")
                        .font(.largeTitle.bold())
                    Text("Challenge ID: \(challengeId)")
                        .foregroundColor(.secondary)
                    Divider()
                    Text("Challenge details will load here.")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Challenge")
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
        case .discovery:
            DiscoveryScreen()
        case .providerDetail(let providerId):
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Provider")
                                .font(.title2.bold())
                            Text("ID: \(providerId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Divider()
                    Text("Provider details, services, and reviews will appear here.")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Provider")
        case .notifications:
            NotificationCenterScreen()
        case .charitySettings:
            CharitySettingsView()
        case .chatList:
            ChatListScreen()
        case .chatDetail(let chatId):
            ChatDetailScreen(chatId: chatId)
        }
    }
}
