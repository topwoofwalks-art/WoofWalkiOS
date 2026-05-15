import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var unreadNotifications = UnreadNotificationsService.shared
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    switch viewModel.uiState {
                    case .loading:
                        placeholderProfile()

                    case .success(let data):
                        profileHeader(user: data.user)

                        walkStreakCard(user: data.user)

                        statsGrid(data: data)

                        walkHistoryPreview()

                        weeklyActivityChart()

                        dogsSection(dogs: data.user.dogs.map(DogProfile.init(from:)))

                        badgesSection()

                        gamificationSection()

                        portalLinkCard()

                        logoutButton()

                    case .error(let message):
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            Text("Error")
                                .font(.title)
                            Text(message)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 100)

                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink(destination: NotificationCenterScreen()) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                if unreadNotifications.unreadCount > 0 {
                                    Text(unreadNotifications.unreadCount > 99 ? "99+" : "\(unreadNotifications.unreadCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red))
                                        .offset(x: 8, y: -6)
                                }
                            }
                        }
                        Button(action: { showEditProfile = true }) {
                            Image(systemName: "pencil")
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    try? AuthService.shared.signOut()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }

    // MARK: - Placeholder Profile (shown when loading or no auth)

    private func placeholderProfile() -> some View {
        VStack(spacing: 16) {
            // Avatar placeholder
            Circle()
                .fill(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                )

            Text("Welcome to WoofWalk")
                .font(.title2.bold())

            Text("Sign in to see your profile")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Demo stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Walks", value: "0", icon: "figure.walk", color: .blue)
                StatCard(title: "Distance", value: "0 km", icon: "map", color: .green)
                StatCard(title: "Time", value: "0h", icon: "clock", color: .orange)
                StatCard(title: "Points", value: "0", icon: "star.fill", color: .purple)
            }
            .padding(.horizontal)

            // Sign in prompt
            Button(action: {}) {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(red: 0/255, green: 160/255, blue: 176/255)))
            }
            .padding(.top, 8)

            // Feature highlights
            VStack(alignment: .leading, spacing: 12) {
                Text("What you can do")
                    .font(.headline)
                    .padding(.horizontal)

                featureRow(icon: "figure.walk", color: .blue, title: "Track Walks", desc: "GPS-tracked walks with stats")
                featureRow(icon: "trophy.fill", color: .orange, title: "Earn Badges", desc: "Complete challenges and level up")
                featureRow(icon: "person.3.fill", color: .purple, title: "Join Community", desc: "Share walks and connect with walkers")
                featureRow(icon: "map.fill", color: .green, title: "Discover Places", desc: "Find dog-friendly pubs, parks & vets")
            }
            .padding(.top, 8)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(color.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Profile Header with League Tier Badge

    private func profileHeader(user: UserProfile) -> some View {
        VStack(spacing: 16) {
            if let photoUrl = user.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 100, height: 100)
            }

            VStack(spacing: 8) {
                Text(user.username)
                    .font(.title)
                    .fontWeight(.bold)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Level \(user.level)")
                            .font(.headline)
                    }

                    // League tier badge
                    leagueTierBadge(tier: user.leagueTier)
                }

                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .foregroundColor(.orange)
                    Text("\(user.pawPoints) points")
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func leagueTierBadge(tier: String?) -> some View {
        let resolvedTier = LeagueTier(rawValue: tier ?? "") ?? .bronze
        let color = leagueTierColor(resolvedTier)
        let name = resolvedTier.displayName

        return HStack(spacing: 4) {
            Image(systemName: "shield.fill")
                .foregroundColor(color)
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private func leagueTierColor(_ tier: LeagueTier) -> Color {
        switch tier {
        case .bronze: return Color(hex: 0xCD7F32)
        case .silver: return Color(hex: 0xC0C0C0)
        case .gold: return Color(hex: 0xFFD700)
        case .sapphire: return Color(hex: 0x0F52BA)
        case .ruby: return Color(hex: 0xE0115F)
        case .emerald: return Color(hex: 0x50C878)
        case .diamond: return Color(hex: 0xB9F2FF)
        }
    }

    // MARK: - Walk Streak Card

    private func walkStreakCard(user: UserProfile) -> some View {
        let streak = user.walkStreak ?? WalkStreak(currentStreak: 5, longestStreak: 14, freezesAvailable: 2)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Walk Streak")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\u{1F525}")
                        .font(.title2)
                    Text("\(streak.currentStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("\u{1F3C6}")
                        .font(.title2)
                    Text("\(streak.longestStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Best")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                if streak.freezesAvailable > 0 {
                    VStack(spacing: 4) {
                        Text("\u{2744}\u{FE0F}")
                            .font(.title2)
                        Text("\(streak.freezesAvailable)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Freezes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    // MARK: - Stats Grid (expanded to 6 items)

    private func statsGrid(data: ProfileData) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Walks",
                value: "\(data.totalWalks)",
                icon: "figure.walk",
                color: .blue
            )

            StatCard(
                title: "Distance",
                value: String(format: "%.1f km", Double(data.totalDistance) / 1000.0),
                icon: "map",
                color: .green
            )

            StatCard(
                title: "Time",
                value: "\(data.totalTime / 60)h",
                icon: "clock",
                color: .orange
            )

            StatCard(
                title: "Points",
                value: "\(data.user.pawPoints)",
                icon: "star.fill",
                color: .purple
            )

            StatCard(
                title: "Contributions",
                value: "\(data.contributions)",
                icon: "star",
                color: .pink
            )

            StatCard(
                title: "Badges",
                value: "\(data.user.badges.count)",
                icon: "rosette",
                color: .indigo
            )
        }
    }

    // MARK: - Walk History Preview

    private func walkHistoryPreview() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Walks")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: WalkHistoryView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if viewModel.recentWalks.isEmpty {
                // Placeholder data when no real walks are available
                ForEach(placeholderWalks, id: \.id) { walk in
                    walkHistoryMiniCard(
                        distance: walk.distance,
                        duration: walk.duration,
                        date: walk.date
                    )
                }
            } else {
                ForEach(viewModel.recentWalks.prefix(3), id: \.id) { walk in
                    walkHistoryMiniCard(
                        distance: walk.distance,
                        duration: walk.duration,
                        date: walk.date
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func walkHistoryMiniCard(distance: String, duration: String, date: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 12) {
                    Label(distance, systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Weekly Activity Chart

    private func weeklyActivityChart() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 4) {
                        let height: CGFloat = viewModel.weeklyWalkData.isEmpty ? 10 :
                            CGFloat(viewModel.weeklyWalkData[index]) * 5 + 10
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(height: height)

                        Text(dayAbbreviation(index: index))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    // MARK: - Dogs Section

    private func dogsSection(dogs: [DogProfile]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Dogs")
                .font(.headline)

            if dogs.isEmpty {
                Text("No dogs added yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(dogs) { dog in
                    NavigationLink(destination: DogStatsScreen(dog: dog)) {
                        DogCard(dog: dog)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    // MARK: - Badges Section

    private func badgesSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(viewModel.badges.prefix(6), id: \.badge.id) { badgeStatus in
                    BadgeView(badgeStatus: badgeStatus)
                }
            }

            NavigationLink(destination: BadgesListView(badges: viewModel.badges)) {
                Text("View All Badges")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    // MARK: - Gamification Section

    private func gamificationSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            NavigationLink(destination: ChallengesScreen()) {
                Label("Challenges", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: LeagueView()) {
                Label("Weekly League", systemImage: "trophy")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    // MARK: - Portal Link Card

    private func portalLinkCard() -> some View {
        Button(action: {
            if let url = URL(string: "https://woofwalk.app") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WoofWalk Portal")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Manage bookings, invoices & more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logout Button

    private func logoutButton() -> some View {
        Button(action: { showLogoutAlert = true }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Log Out")
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .shadow(radius: 2)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func dayAbbreviation(index: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][index]
    }

    // Placeholder walk data for when no real walks exist
    private var placeholderWalks: [PlaceholderWalk] {
        [
            PlaceholderWalk(id: "1", distance: "2.3 km", duration: "35 min", date: "Today"),
            PlaceholderWalk(id: "2", distance: "1.8 km", duration: "28 min", date: "Yesterday"),
            PlaceholderWalk(id: "3", distance: "3.1 km", duration: "45 min", date: "Mar 15"),
        ]
    }
}

// MARK: - Placeholder Walk Model

private struct PlaceholderWalk: Identifiable {
    let id: String
    let distance: String
    let duration: String
    let date: String
}

// MARK: - Recent Walk Display Model

struct RecentWalkDisplay: Identifiable {
    let id: String
    let distance: String
    let duration: String
    let date: String
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct DogCard: View {
    let dog: DogProfile

    var body: some View {
        HStack(spacing: 12) {
            if let photoUrl = dog.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text("\u{1F415}")
                        .font(.largeTitle)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Text("\u{1F415}")
                    .font(.largeTitle)
                    .frame(width: 50, height: 50)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.headline)

                Text("\(dog.breed) \u{2022} \(dog.age) years")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if dog.nervousDog {
                    Label("Nervous Dog", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BadgeView: View {
    let badgeStatus: BadgeWithStatus

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badgeStatus.isUnlocked ?
                          badgeStatus.badge.rarity.color.opacity(0.2) :
                          Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: badgeStatus.badge.iconName)
                    .font(.title2)
                    .foregroundColor(badgeStatus.isUnlocked ?
                                   badgeStatus.badge.rarity.color :
                                   .gray)
            }

            Text(badgeStatus.badge.name)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !badgeStatus.isUnlocked {
                ProgressView(value: badgeStatus.progress)
                    .frame(width: 50)
            }
        }
        .opacity(badgeStatus.isUnlocked ? 1.0 : 0.5)
    }
}

struct BadgesListView: View {
    let badges: [BadgeWithStatus]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                ForEach(badges, id: \.badge.id) { badgeStatus in
                    VStack(spacing: 8) {
                        BadgeView(badgeStatus: badgeStatus)

                        Text(badgeStatus.badge.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        if !badgeStatus.isUnlocked {
                            Text("\(badgeStatus.currentValue)/\(badgeStatus.targetValue)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
            }
            .padding()
        }
        .navigationTitle("All Badges")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
