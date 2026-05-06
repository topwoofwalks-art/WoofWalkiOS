import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedType: LeaderboardType = .global
    @State private var showPointsGuide = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                leaderboardTypePicker()

                switch viewModel.leaderboardState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded(let users):
                    if users.isEmpty {
                        emptyLeaderboardView()
                    } else {
                        leaderboardList(users: users)
                    }

                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showPointsGuide = true }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showPointsGuide) {
                PointsGuideSheet()
            }
            .onAppear {
                viewModel.loadLeaderboard(type: selectedType)
            }
        }
    }

    private func leaderboardTypePicker() -> some View {
        Picker("Type", selection: $selectedType) {
            ForEach(LeaderboardType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .onChange(of: selectedType) { newValue in
            viewModel.loadLeaderboard(type: newValue)
        }
    }

    private func leaderboardList(users: [UserProfile]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(users.enumerated()), id: \.offset) { index, user in
                    LeaderboardRow(
                        rank: index + 1,
                        user: user,
                        isCurrentUser: false
                    )
                    Divider()
                }
            }
        }
    }

    private func emptyLeaderboardView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No-one to show yet")
                .font(.title3)
            Text(selectedType == .friends
                 ? "Add friends from the Social tab to see them here."
                 : "Be the first to log a walk in your area.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Error")
                .font(.title)

            Text(message)
                .foregroundColor(.secondary)

            Button("Retry") {
                viewModel.loadLeaderboard(type: selectedType)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let user: UserProfile
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 16) {
            rankBadge()

            UserAvatarView(
                photoUrl: user.photoUrl,
                displayName: user.username,
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.username)
                        .font(.headline)

                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                HStack(spacing: 12) {
                    Label("Level \(user.level)", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Label("\(user.totalWalks) walks", systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(user.pawPoints)")
                        .font(.headline)
                }

                if user.totalDistanceMeters > 0 {
                    Text(String(format: "%.1f km", user.totalDistanceMeters / 1000.0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isCurrentUser ? Color.blue.opacity(0.1) : Color.clear)
    }

    private func rankBadge() -> some View {
        ZStack {
            Circle()
                .fill(rankColor())
                .frame(width: 32, height: 32)

            if rank <= 3 {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundColor(.white)
            } else {
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }

    private func rankColor() -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .blue
        }
    }
}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        LeaderboardView()
    }
}
