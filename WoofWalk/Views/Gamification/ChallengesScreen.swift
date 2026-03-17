import SwiftUI
import Combine

struct ChallengesScreen: View {
    @StateObject private var viewModel = ChallengesViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(ChallengeCategory.allCases, id: \.self) { category in
                    let filtered = viewModel.challenges.filter { $0.category == category }
                    if !filtered.isEmpty {
                        Section {
                            ForEach(filtered) { challenge in
                                ChallengeCard(challenge: challenge, onJoin: { viewModel.joinChallenge(challenge.id ?? "") })
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
            .padding(.vertical)
        }
        .navigationTitle("Challenges")
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
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
                }
                Spacer()
                Text("\(challenge.participantCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    private let repository = ChallengeRepository()
    private var cancellable: AnyCancellable?

    init() {
        cancellable = repository.getActiveChallenges()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in self?.challenges = $0 })
    }

    func joinChallenge(_ id: String) {
        Task { try? await repository.joinChallenge(id) }
    }
}
