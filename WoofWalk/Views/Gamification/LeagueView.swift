import SwiftUI

struct LeagueView: View {
    @StateObject private var viewModel = LeagueViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let state = viewModel.leagueState {
                    // Tier badge
                    LeagueTierBadge(tier: state.tier)
                        .padding(.top)

                    // Leaderboard
                    VStack(spacing: 0) {
                        ForEach(state.participants) { participant in
                            HStack(spacing: 12) {
                                Text("#\(participant.rank)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(rankColor(participant.rank))
                                    .frame(width: 32)

                                Circle()
                                    .fill(Color.neutral90)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if let url = participant.photoUrl, let imgUrl = URL(string: url) {
                                            AsyncImage(url: imgUrl) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                                                .clipShape(Circle())
                                        } else {
                                            Text(String(participant.displayName.prefix(1)))
                                                .font(.subheadline.bold())
                                        }
                                    }

                                Text(participant.displayName)
                                    .font(.subheadline)
                                    .fontWeight(participant.userId == state.currentUserId ? .bold : .regular)

                                Spacer()

                                Text("\(participant.weeklyPoints) pts")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.turquoise60)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(participant.userId == state.currentUserId ? Color.turquoise90.opacity(0.3) : Color.clear)

                            if participant.rank < state.participants.count {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
                    .padding(.horizontal)
                } else if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    Text("No league data available")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            }
        }
        .navigationTitle("Weekly League")
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
}

struct LeagueTierBadge: View {
    let tier: LeagueTier

    var tierColor: Color {
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

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.fill")
                .font(.system(size: 48))
                .foregroundColor(tierColor)
            Text(tier.displayName)
                .font(.title3)
                .fontWeight(.bold)
            Text("League")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

@MainActor
class LeagueViewModel: ObservableObject {
    @Published var leagueState: WeeklyLeagueState?
    @Published var isLoading = false
    private let repository = LeagueRepository()

    init() { load() }

    func load() {
        isLoading = true
        Task {
            leagueState = try? await repository.getCurrentLeagueState()
            isLoading = false
        }
    }
}
