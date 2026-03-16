import SwiftUI

struct LeaderboardView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedType: LeaderboardType = .global

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                leaderboardTypePicker()

                switch viewModel.uiState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .leaderboardLoaded(let users):
                    leaderboardList(users: users)

                case .error(let message):
                    errorView(message: message)

                default:
                    EmptyView()
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
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
                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
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
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 50)
            }

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
