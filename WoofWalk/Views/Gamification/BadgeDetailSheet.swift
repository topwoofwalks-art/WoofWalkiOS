import SwiftUI

struct BadgeDetailSheet: View {
    let badgeId: String

    @Environment(\.dismiss) private var dismiss

    private var badge: Badge? {
        BadgeDefinitions.getBadge(id: badgeId)
    }

    var body: some View {
        ScrollView {
            if let badge = badge {
                badgeContent(badge)
            } else {
                badgeNotFound
            }
        }
        .navigationTitle("Badge Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Badge Content

    private func badgeContent(_ badge: Badge) -> some View {
        VStack(spacing: 24) {
            // Badge Icon
            ZStack {
                Circle()
                    .fill(badge.rarity.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                Circle()
                    .strokeBorder(badge.rarity.color, lineWidth: 3)
                    .frame(width: 120, height: 120)
                Image(systemName: badge.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(badge.rarity.color)
            }
            .padding(.top, 24)

            // Badge Name & Rarity
            VStack(spacing: 8) {
                Text(badge.name)
                    .font(.title.bold())
                HStack(spacing: 6) {
                    Image(systemName: rarityIcon(badge.rarity))
                        .foregroundColor(badge.rarity.color)
                    Text(badge.rarity.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(badge.rarity.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(badge.rarity.color.opacity(0.1))
                .cornerRadius(12)
            }

            // Description
            Text(badge.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Requirements Card
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.accentColor)
                    Text("Requirements")
                        .font(.headline)
                    Spacer()
                }

                requirementRow(badge)

                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("0 / \(badge.unlockCriteria.targetValue)")
                            .font(.caption.bold())
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(badge.rarity.color)
                                .frame(width: 0) // 0 progress for now
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)

            // Category
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.accentColor)
                    Text("Category")
                        .font(.headline)
                    Spacer()
                }
                HStack {
                    Image(systemName: badge.category.icon)
                        .foregroundColor(.accentColor)
                    Text(badge.category.displayName)
                        .font(.body)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)

            // Tips section
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Tips to Earn")
                        .font(.headline)
                    Spacer()
                }
                Text(tipText(for: badge))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)

            Spacer(minLength: 40)
        }
    }

    // MARK: - Requirement Row

    private func requirementRow(_ badge: Badge) -> some View {
        HStack {
            Image(systemName: criteriaIcon(badge.unlockCriteria.type))
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text(criteriaText(badge.unlockCriteria))
                .font(.subheadline)
            Spacer()
            Image(systemName: "circle")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func rarityIcon(_ rarity: BadgeRarity) -> String {
        switch rarity {
        case .common: return "circle"
        case .rare: return "diamond"
        case .epic: return "star.fill"
        case .legendary: return "crown.fill"
        }
    }

    private func criteriaIcon(_ type: CriteriaType) -> String {
        switch type {
        case .walksCompleted: return "figure.walk"
        case .distanceTotal: return "ruler"
        case .poisCreated: return "mappin.circle"
        case .votesGiven: return "hand.thumbsup"
        case .timeOfDay: return "clock"
        case .special: return "sparkles"
        }
    }

    private func criteriaText(_ criteria: BadgeCriteria) -> String {
        switch criteria.type {
        case .walksCompleted: return "Complete \(criteria.targetValue) walks"
        case .distanceTotal: return "Walk \(criteria.targetValue >= 1000 ? "\(criteria.targetValue / 1000) km" : "\(criteria.targetValue) m") total"
        case .poisCreated: return "Create \(criteria.targetValue) points of interest"
        case .votesGiven: return "Vote on \(criteria.targetValue) points of interest"
        case .timeOfDay: return "Walk at a specific time"
        case .special: return "Special achievement"
        }
    }

    private func tipText(for badge: Badge) -> String {
        switch badge.unlockCriteria.type {
        case .walksCompleted: return "Keep walking regularly! Every walk counts towards this badge. Try to walk at least once a day."
        case .distanceTotal: return "Longer walks help you progress faster. Try exploring new routes to cover more ground."
        case .poisCreated: return "Look for interesting spots during your walks and mark them as points of interest for the community."
        case .votesGiven: return "Help the community by voting on points of interest. Upvote helpful ones and downvote outdated ones."
        case .timeOfDay: return "Try walking at different times of day to discover new things about your neighbourhood."
        case .special: return "This is a special badge. Keep engaging with the WoofWalk community!"
        }
    }

    // MARK: - Not Found

    private var badgeNotFound: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "trophy.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Badge Not Found")
                .font(.headline)
            Text("This badge may have been removed or is no longer available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Level Up Screen

struct LevelUpScreen: View {
    @Environment(\.dismiss) private var dismiss

    private let currentLevel: Int = 5
    private let currentXP: Int = 2350
    private let nextLevelXP: Int = 3000
    private let totalXP: Int = 12350

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Level Badge
                levelBadge
                    .padding(.top, 24)

                // XP Progress
                xpProgressSection

                // Level Benefits
                levelBenefitsSection

                // XP Breakdown
                xpBreakdownSection

                // Recent XP Gains
                recentXPSection

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Level Progress")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Level Badge

    private var levelBadge: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .orange.opacity(0.3), radius: 12)
                VStack(spacing: 0) {
                    Text("LVL")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(currentLevel)")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundColor(.white)
                }
            }
            Text("Walker")
                .font(.title2.bold())
            Text("\(totalXP) total XP earned")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - XP Progress

    private var xpProgressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Level \(currentLevel)")
                    .font(.subheadline.bold())
                Spacer()
                Text("Level \(currentLevel + 1)")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(currentXP) / CGFloat(nextLevelXP))
                }
            }
            .frame(height: 16)

            Text("\(currentXP) / \(nextLevelXP) XP")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Level Benefits

    private var levelBenefitsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.purple)
                Text("Level \(currentLevel) Benefits")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 8) {
                benefitRow(icon: "camera.fill", text: "Walk photo gallery unlocked", unlocked: true)
                benefitRow(icon: "person.2.fill", text: "Follow up to 100 walkers", unlocked: true)
                benefitRow(icon: "paintbrush.fill", text: "Custom profile themes", unlocked: true)
                benefitRow(icon: "map.fill", text: "Route creation tools", unlocked: false)
                benefitRow(icon: "trophy.fill", text: "Leaderboard badges", unlocked: false)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func benefitRow(icon: String, text: String, unlocked: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(unlocked ? .accentColor : .secondary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(unlocked ? .primary : .secondary)
            Spacer()
            Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                .foregroundColor(unlocked ? .green : .secondary)
                .font(.caption)
        }
    }

    // MARK: - XP Breakdown

    private var xpBreakdownSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("How to Earn XP")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 8) {
                xpRow(action: "Complete a walk", xp: 50)
                xpRow(action: "Walk 1 km", xp: 10)
                xpRow(action: "Create a POI", xp: 25)
                xpRow(action: "Get a vote on your POI", xp: 5)
                xpRow(action: "Share a walk post", xp: 15)
                xpRow(action: "Maintain daily streak", xp: 30)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func xpRow(action: String, xp: Int) -> some View {
        HStack {
            Text(action)
                .font(.subheadline)
            Spacer()
            Text("+\(xp) XP")
                .font(.subheadline.bold())
                .foregroundColor(.orange)
        }
    }

    // MARK: - Recent XP

    private var recentXPSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.green)
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 8) {
                recentRow(desc: "Morning walk with Bella", xp: 75, time: "2h ago")
                recentRow(desc: "Marked a new water source", xp: 25, time: "Yesterday")
                recentRow(desc: "7-day streak bonus", xp: 30, time: "Yesterday")
                recentRow(desc: "Evening walk", xp: 50, time: "2 days ago")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func recentRow(desc: String, xp: Int, time: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(desc)
                    .font(.subheadline)
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("+\(xp)")
                .font(.subheadline.bold())
                .foregroundColor(.green)
        }
    }
}
