import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    switch viewModel.uiState {
                    case .loading:
                        ProgressView()
                            .padding(.top, 100)

                    case .success(let data):
                        profileHeader(user: data.user)

                        statsGrid(data: data)

                        weeklyActivityChart()

                        dogsSection(dogs: data.user.dogs)

                        badgesSection()

                        gamificationSection()

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

                    case .leaderboardLoaded:
                        EmptyView()
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
                            Image(systemName: "bell")
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
        }
    }

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

                    HStack(spacing: 4) {
                        Image(systemName: "pawprint.fill")
                            .foregroundColor(.orange)
                        Text("\(user.pawPoints) points")
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func statsGrid(data: ProfileData) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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
                title: "Contributions",
                value: "\(data.contributions)",
                icon: "star",
                color: .purple
            )
        }
    }

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

    private func dayAbbreviation(index: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][index]
    }
}

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
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
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
                    Text("🐕")
                        .font(.largeTitle)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Text("🐕")
                    .font(.largeTitle)
                    .frame(width: 50, height: 50)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.headline)

                Text("\(dog.breed) • \(dog.age) years")
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
