import SwiftUI
import Combine
import FirebaseAuth

struct ChallengesScreen: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @State private var selectedTab: ChallengeTab = .active

    enum ChallengeTab: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $selectedTab) {
                ForEach(ChallengeTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                LazyVStack(spacing: 16) {
                    let filtered = filteredChallenges
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(ChallengeCategory.allCases, id: \.self) { category in
                            let catFiltered = filtered.filter { $0.category == category }
                            if !catFiltered.isEmpty {
                                Section {
                                    ForEach(catFiltered) { challenge in
                                        NavigationLink(value: AppRoute.challengeDetail(challengeId: challenge.id ?? "")) {
                                            ChallengeCard(
                                                challenge: challenge,
                                                userProgress: viewModel.userProgress[challenge.id ?? ""],
                                                onJoin: { viewModel.joinChallenge(challenge.id ?? "") }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } header: {
                                    Text(category.rawValue.capitalized)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Challenges")
    }

    private var filteredChallenges: [Challenge] {
        let uid = Auth.auth().currentUser?.uid
        switch selectedTab {
        case .active:
            return viewModel.challenges.filter { $0.isActive }
        case .completed:
            // Challenges the user has completed (progress >= target)
            return viewModel.challenges.filter { challenge in
                guard let id = challenge.id,
                      let progress = viewModel.userProgress[id] else { return false }
                return progress >= challenge.target
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedTab == .active ? "trophy" : "checkmark.seal")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(selectedTab == .active ? "No active challenges" : "No completed challenges yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    var userProgress: Double?
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(challenge.iconEmoji)
                    .font(.title)
                VStack(alignment: .leading) {
                    Text(challenge.title)
                        .font(.headline)
                    Text(challenge.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(challenge.participantCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            if let progress = userProgress {
                let fraction = challenge.target > 0 ? min(progress / challenge.target, 1.0) : 0
                VStack(alignment: .leading, spacing: 2) {
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

                    HStack {
                        Text("\(String(format: "%.0f", progress)) / \(String(format: "%.0f", challenge.target)) \(challenge.unit)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        if fraction >= 1.0 {
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            HStack {
                Text("Target: \(String(format: "%.0f", challenge.target)) \(challenge.unit)")
                    .font(.caption)
                    .foregroundColor(.turquoise60)
                Spacer()
                Button("Join", action: onJoin)
                    .font(.caption.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.turquoise60))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
        .padding(.horizontal)
    }
}

@MainActor
class ChallengesViewModel: ObservableObject {
    @Published var challenges: [Challenge] = []
    @Published var userProgress: [String: Double] = [:]
    private let repository = ChallengeRepository.shared
    private var cancellable: AnyCancellable?

    init() {
        // Ensure default challenges exist before listening
        Task {
            await repository.ensureDefaultChallengesExist()
        }

        cancellable = repository.getActiveChallenges()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] challenges in
                self?.challenges = challenges
                self?.loadUserProgress(challenges: challenges)
            })
    }

    func joinChallenge(_ id: String) {
        Task { try? await repository.joinChallenge(id) }
    }

    private func loadUserProgress(challenges: [Challenge]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        for challenge in challenges {
            guard let id = challenge.id,
                  challenge.participantIds.contains(uid) else { continue }
            Task {
                let participants = try? await repository.getLeaderboard(challengeId: id)
                if let entry = participants?.first(where: { $0.userId == uid }) {
                    self.userProgress[id] = entry.progress
                }
            }
        }
    }
}
