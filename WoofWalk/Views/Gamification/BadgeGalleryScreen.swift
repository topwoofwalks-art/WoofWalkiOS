import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - View Model

@MainActor
class BadgeGalleryViewModel: ObservableObject {
    @Published var unlockedBadgeIds: Set<String> = []
    @Published var userStats: UserBadgeStats = UserBadgeStats()
    @Published var isLoading = true
    @Published var selectedBadge: Badge? = nil

    private let db = Firestore.firestore()

    var allBadges: [Badge] { BadgeDefinitions.allBadges }
    var unlockedCount: Int { unlockedBadgeIds.count }
    var totalCount: Int { allBadges.count }

    func badges(for category: BadgeCategory) -> [Badge] {
        if category == .all { return allBadges }
        return allBadges.filter { $0.category == category }
    }

    func isUnlocked(_ badge: Badge) -> Bool {
        unlockedBadgeIds.contains(badge.id)
    }

    func progress(for badge: Badge) -> Double {
        let current: Double
        switch badge.unlockCriteria.type {
        case .walksCompleted:
            current = Double(userStats.totalWalks)
        case .distanceTotal:
            current = userStats.totalDistance
        case .poisCreated:
            current = Double(userStats.poisCreated)
        case .votesGiven:
            current = Double(userStats.votesGiven)
        case .timeOfDay, .special:
            return 0
        }
        let target = Double(badge.unlockCriteria.targetValue)
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    func loadData() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let data = doc.data() ?? [:]
            let badges = data["badges"] as? [String] ?? []
            unlockedBadgeIds = Set(badges)
            userStats = UserBadgeStats(
                totalWalks: data["totalWalks"] as? Int ?? 0,
                totalDistance: data["totalDistance"] as? Double ?? 0,
                poisCreated: data["poisCreated"] as? Int ?? 0,
                votesGiven: data["votesGiven"] as? Int ?? 0
            )
        } catch {
            print("BadgeGallery load error: \(error)")
        }
        isLoading = false
    }
}

struct UserBadgeStats {
    var totalWalks: Int = 0
    var totalDistance: Double = 0
    var poisCreated: Int = 0
    var votesGiven: Int = 0
}

// MARK: - Badge Gallery Screen

struct BadgeGalleryScreen: View {
    @StateObject private var vm = BadgeGalleryViewModel()
    @State private var selectedCategory: BadgeCategory = .all

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Category chips
                categoryChips

                // Badge grid
                badgeGrid
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Badge Gallery")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.loadData() }
        .sheet(item: $vm.selectedBadge) { badge in
            BadgeDetailSheet(
                badge: badge,
                isUnlocked: vm.isUnlocked(badge),
                progress: vm.progress(for: badge)
            )
            .presentationDetents([.medium])
        }
        .overlay {
            if vm.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text("Badge Collection")
                    .font(.title3.bold())
                Spacer()
                Text("\(vm.unlockedCount)/\(vm.totalCount)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(vm.unlockedCount), total: Double(max(vm.totalCount, 1)))
                .tint(.orange)
                .scaleEffect(y: 1.5, anchor: .center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BadgeCategory.allCases) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Badge Grid

    private var badgeGrid: some View {
        let badges = vm.badges(for: selectedCategory)
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(badges) { badge in
                BadgeCell(
                    badge: badge,
                    isUnlocked: vm.isUnlocked(badge),
                    progress: vm.progress(for: badge)
                )
                .onTapGesture {
                    vm.selectedBadge = badge
                }
            }
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.orange : Color(.systemGray5))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge Cell

private struct BadgeCell: View {
    let badge: Badge
    let isUnlocked: Bool
    let progress: Double

    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .fill(isUnlocked ? badge.rarity.color.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 72, height: 72)

                // Glow for unlocked
                if isUnlocked {
                    Circle()
                        .fill(badge.rarity.color.opacity(0.08))
                        .frame(width: 88, height: 88)
                        .blur(radius: 8)
                }

                // Icon
                if isUnlocked {
                    Image(systemName: badge.iconName)
                        .font(.system(size: 28))
                        .foregroundStyle(badge.rarity.color)
                        .overlay(
                            Image(systemName: badge.iconName)
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .clear],
                                        startPoint: shimmer ? .trailing : .leading,
                                        endPoint: shimmer ? .leading : .trailing
                                    )
                                )
                                .mask(
                                    Image(systemName: badge.iconName)
                                        .font(.system(size: 28))
                                )
                        )
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(.systemGray3))
                }
            }
            .frame(width: 88, height: 88)

            // Name
            Text(badge.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .frame(height: 32)

            // Progress bar for locked
            if !isUnlocked && badge.unlockCriteria.type != .special && badge.unlockCriteria.type != .timeOfDay {
                ProgressView(value: progress)
                    .tint(.orange)
                    .frame(width: 56)
            }
        }
        .onAppear {
            if isUnlocked {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...1))
                ) {
                    shimmer = true
                }
            }
        }
    }
}

// MARK: - Badge Detail Sheet

private struct BadgeDetailSheet: View {
    let badge: Badge
    let isUnlocked: Bool
    let progress: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Drag indicator
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            // Large icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? badge.rarity.color.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 120, height: 120)

                if isUnlocked {
                    Circle()
                        .fill(badge.rarity.color.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .blur(radius: 12)

                    Image(systemName: badge.iconName)
                        .font(.system(size: 52))
                        .foregroundStyle(badge.rarity.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(.systemGray3))
                }
            }

            // Badge name
            Text(badge.name)
                .font(.title2.bold())

            // Rarity tag
            Text(badge.rarity.displayName)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(badge.rarity.color.opacity(0.15))
                )
                .foregroundStyle(badge.rarity.color)

            // Description
            Text(badge.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Unlock criteria / progress
            if isUnlocked {
                Label("Unlocked", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                VStack(spacing: 8) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ProgressView(value: progress)
                        .tint(.orange)
                        .frame(width: 200)
                        .scaleEffect(y: 1.5, anchor: .center)

                    Text(criteriaText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text(isUnlocked ? "Nice!" : "Keep Going!")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isUnlocked ? badge.rarity.color : .orange)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }

    private var criteriaText: String {
        let target = badge.unlockCriteria.targetValue
        switch badge.unlockCriteria.type {
        case .walksCompleted:
            return "Complete \(target) walks"
        case .distanceTotal:
            let km = Double(target) / 1000.0
            return "Walk \(String(format: "%.1f", km)) km total"
        case .poisCreated:
            return "Create \(target) points of interest"
        case .votesGiven:
            return "Vote on \(target) places"
        case .timeOfDay:
            return "Walk at a special time"
        case .special:
            return "Special achievement"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BadgeGalleryScreen()
    }
}
