import SwiftUI
import FirebaseAuth

struct ChallengeDetailScreen: View {
    let challengeId: String
    @StateObject private var viewModel: ChallengeDetailViewModel

    init(challengeId: String) {
        self.challengeId = challengeId
        _viewModel = StateObject(wrappedValue: ChallengeDetailViewModel(challengeId: challengeId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading challenge...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let challenge = viewModel.challenge {
                ScrollView {
                    VStack(spacing: 24) {
                        headerCard(challenge)
                        statsRow(challenge)
                        joinButton(challenge)
                        leaderboardSection(challenge)
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Challenge not found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Challenge")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card

    @ViewBuilder
    private func headerCard(_ challenge: Challenge) -> some View {
        VStack(spacing: 12) {
            Text(challenge.iconEmoji)
                .font(.system(size: 64))

            Text(challenge.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(challenge.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            categoryChip(challenge.category)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
    }

    @ViewBuilder
    private func categoryChip(_ category: ChallengeCategory) -> some View {
        Text(category.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(categoryColor(category).opacity(0.15)))
            .foregroundColor(categoryColor(category))
    }

    private func categoryColor(_ category: ChallengeCategory) -> Color {
        switch category {
        case .daily: return .orange
        case .weekly: return .blue
        case .monthly: return .purple
        case .special: return .pink
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    private func statsRow(_ challenge: Challenge) -> some View {
        HStack(spacing: 0) {
            statColumn(
                label: "Joined",
                value: "\(challenge.participantCount)",
                icon: "person.2.fill"
            )

            Divider()
                .frame(height: 48)

            statColumn(
                label: "Target",
                value: "\(String(format: "%.0f", challenge.target)) \(challenge.unit)",
                icon: "flag.fill"
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func statColumn(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.turquoise60)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Join Button

    @ViewBuilder
    private func joinButton(_ challenge: Challenge) -> some View {
        let isJoined = viewModel.isJoined
        Button {
            if !isJoined {
                viewModel.joinChallenge()
            }
        } label: {
            HStack {
                Image(systemName: isJoined ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isJoined ? "Joined" : "Join Challenge")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isJoined ? Color.gray.opacity(0.3) : Color.turquoise60)
            )
            .foregroundColor(isJoined ? .secondary : .white)
        }
        .disabled(isJoined || viewModel.isJoining)
    }

    // MARK: - Leaderboard

    @ViewBuilder
    private func leaderboardSection(_ challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leaderboard")
                .font(.headline)

            if viewModel.leaderboard.isEmpty {
                emptyLeaderboard
            } else {
                ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.userId) { index, entry in
                    leaderboardRow(entry: entry, rank: index + 1, target: challenge.target)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyLeaderboard: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy")
                .font(.title)
                .foregroundColor(.secondary)
            Text("No participants yet. Be the first!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private func leaderboardRow(entry: ChallengeParticipant, rank: Int, target: Double) -> some View {
        HStack(spacing: 12) {
            rankBadge(rank)

            avatarCircle(name: entry.userName)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.userName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    progressBar(progress: entry.progress, target: target)
                    Text("\(String(format: "%.0f", entry.progress))/\(String(format: "%.0f", target))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
            }

            if entry.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.body)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func rankBadge(_ rank: Int) -> some View {
        Text("#\(rank)")
            .font(.caption.bold())
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(rankColor(rank)))
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)    // gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)   // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)   // bronze
        default: return .gray
        }
    }

    @ViewBuilder
    private func avatarCircle(name: String) -> some View {
        let initial = String(name.prefix(1)).uppercased()
        Text(initial)
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.turquoise60))
    }

    @ViewBuilder
    private func progressBar(progress: Double, target: Double) -> some View {
        let fraction = target > 0 ? min(progress / target, 1.0) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                Capsule()
                    .fill(fraction >= 1.0 ? Color.green : Color.turquoise60)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - ViewModel

@MainActor
class ChallengeDetailViewModel: ObservableObject {
    @Published var challenge: Challenge?
    @Published var leaderboard: [ChallengeParticipant] = []
    @Published var isLoading = true
    @Published var isJoined = false
    @Published var isJoining = false

    private let challengeId: String
    private let repository = ChallengeRepository()

    init(challengeId: String) {
        self.challengeId = challengeId
        Task { await load() }
    }

    func load() async {
        isLoading = true
        do {
            let doc = try await repository.getChallenge(byId: challengeId)
            challenge = doc
            if let uid = Auth.auth().currentUser?.uid,
               let challenge = doc {
                isJoined = challenge.participantIds.contains(uid)
            }
            leaderboard = try await repository.getLeaderboard(challengeId: challengeId)
        } catch {
            print("Failed to load challenge: \(error)")
        }
        isLoading = false
    }

    func joinChallenge() {
        isJoining = true
        Task {
            try? await repository.joinChallenge(challengeId)
            isJoined = true
            isJoining = false
            // Refresh leaderboard
            leaderboard = (try? await repository.getLeaderboard(challengeId: challengeId)) ?? leaderboard
        }
    }
}
