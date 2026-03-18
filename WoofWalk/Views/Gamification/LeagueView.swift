import SwiftUI

struct LeagueView: View {
    @StateObject private var viewModel = LeagueViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let state = viewModel.leagueState {
                    // Tier Header
                    TierHeader(tier: state.tier, countdownText: viewModel.countdownText)

                    // Status Banner
                    StatusBanner(state: state)

                    // Zone Legend
                    ZoneLegend()
                        .padding(.horizontal)
                        .padding(.top, 12)

                    // Leaderboard
                    VStack(spacing: 0) {
                        ForEach(state.participants) { participant in
                            ParticipantRow(
                                participant: participant,
                                totalCount: state.participants.count,
                                isCurrentUser: participant.userId == state.currentUserId
                            )

                            if participant.rank < state.participants.count {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

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
        .task {
            while !Task.isCancelled {
                viewModel.updateCountdown()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            }
        }
    }
}

// MARK: - Tier Header

private struct TierHeader: View {
    let tier: LeagueTier
    let countdownText: String

    var body: some View {
        VStack(spacing: 8) {
            Text(tier.tierEmoji)
                .font(.system(size: 56))

            Text(tier.displayName + " League")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(countdownText)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.2)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: tier.tierGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Status Banner

private struct StatusBanner: View {
    let state: WeeklyLeagueState

    var body: some View {
        if state.isInPromotionZone {
            bannerView(
                text: "You're in the promotion zone!",
                icon: "arrow.up.circle.fill",
                color: .green
            )
        } else if state.isInDemotionZone {
            bannerView(
                text: "Watch out - demotion zone!",
                icon: "arrow.down.circle.fill",
                color: .red
            )
        }
    }

    @ViewBuilder
    private func bannerView(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color)
    }
}

// MARK: - Zone Legend

private struct ZoneLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            legendDot(color: .green, label: "Promotion")
            legendDot(color: .gray.opacity(0.4), label: "Safe")
            legendDot(color: .red, label: "Demotion")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Participant Row

private struct ParticipantRow: View {
    let participant: RankedParticipant
    let totalCount: Int
    let isCurrentUser: Bool

    private var isPromotionZone: Bool { participant.rank <= WeeklyLeagueState.promotionCutoff }
    private var isDemotionZone: Bool { participant.rank > totalCount - WeeklyLeagueState.demotionCutoff }

    private var zoneBackground: Color {
        if isPromotionZone { return Color.green.opacity(0.08) }
        if isDemotionZone { return Color.red.opacity(0.08) }
        return Color.clear
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            rankBadge

            // Avatar
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

            // Name
            Text(participant.displayName)
                .font(.subheadline)
                .fontWeight(isCurrentUser ? .bold : .regular)
                .lineLimit(1)

            Spacer()

            // Points
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.turquoise60)
                Text("\(participant.weeklyPoints)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.turquoise60)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: isCurrentUser ? 10 : 0)
                .fill(isCurrentUser ? Color.turquoise90.opacity(0.3) : zoneBackground)
                .shadow(color: isCurrentUser ? Color.black.opacity(0.06) : .clear, radius: isCurrentUser ? 3 : 0, y: isCurrentUser ? 1 : 0)
        )
    }

    @ViewBuilder
    private var rankBadge: some View {
        if participant.rank <= 3 {
            ZStack {
                Circle()
                    .fill(medalColor)
                    .frame(width: 28, height: 28)
                Text("\(participant.rank)")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
            }
            .frame(width: 32)
        } else {
            Text("#\(participant.rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 32)
        }
    }

    private var medalColor: Color {
        switch participant.rank {
        case 1: return Color(hex: 0xFFD700)
        case 2: return Color(hex: 0xC0C0C0)
        case 3: return Color(hex: 0xCD7F32)
        default: return .secondary
        }
    }
}

// MARK: - View Model

@MainActor
class LeagueViewModel: ObservableObject {
    @Published var leagueState: WeeklyLeagueState?
    @Published var isLoading = false
    @Published var countdownText: String = ""
    private let repository = LeagueRepository()

    init() {
        updateCountdown()
        load()
    }

    func load() {
        isLoading = true
        Task {
            leagueState = try? await repository.getCurrentLeagueState()
            isLoading = false
        }
    }

    func updateCountdown() {
        let calendar = Calendar(identifier: .iso8601)
        let now = Date()

        // End of current ISO week = next Monday 00:00:00 UTC
        guard let nextMonday = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: 2),
            matchingPolicy: .nextTime
        ) else {
            countdownText = "--"
            return
        }

        let remaining = nextMonday.timeIntervalSince(now)
        guard remaining > 0 else {
            countdownText = "Ending soon"
            return
        }

        let totalMinutes = Int(remaining) / 60
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes % (60 * 24)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            countdownText = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            countdownText = "\(hours)h \(minutes)m"
        } else {
            countdownText = "\(minutes)m"
        }
    }
}
