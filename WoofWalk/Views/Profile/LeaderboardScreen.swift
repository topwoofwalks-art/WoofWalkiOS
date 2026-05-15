import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Multi-period, multi-metric leaderboard screen — iOS port of the Android
/// `LeaderboardScreen.kt`. Reads pre-computed leaderboard docs from
/// `leaderboards/{period}_{metric}` (e.g. `weekly_charity_points`,
/// `all_time_walk_distance`). When the doc doesn't exist yet (cold start
/// before the CF has run), shows a polished empty state inviting the user
/// to be first on the board.
///
/// Note: `LeaderboardView.swift` (the older single-metric screen still wired
/// into `SocialHubScreen`) is intentionally left untouched. This is a new
/// route reached from the Profile menu — see the "Leaderboard" row added to
/// `ProfileView.swift`'s gamification section.
struct LeaderboardScreen: View {
    @State private var selectedPeriod: LeaderboardPeriod = .weekly
    @State private var selectedMetric: LeaderboardMetric = .charityPoints
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading: Bool = true
    @State private var loadError: String? = nil
    @State private var currentUserId: String? = Auth.auth().currentUser?.uid

    private let db = Firestore.firestore()
    private let pageSize: Int = 100

    var body: some View {
        VStack(spacing: 0) {
            periodTabs
            metricChips

            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    errorState(err)
                } else if entries.isEmpty {
                    emptyState
                } else {
                    leaderboardList
                }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await reload() } }
        .onChange(of: selectedPeriod) { _ in Task { await reload() } }
        .onChange(of: selectedMetric) { _ in Task { await reload() } }
    }

    // MARK: - Period tabs

    private var periodTabs: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(LeaderboardPeriod.allCases, id: \.self) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Metric chips

    private var metricChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LeaderboardMetric.allCases, id: \.self) { metric in
                    let selected = metric == selectedMetric
                    Button {
                        selectedMetric = metric
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: metric.iconSystemName)
                                .font(.caption)
                            Text(metric.title)
                                .font(.subheadline)
                                .fontWeight(selected ? .semibold : .regular)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                selected
                                    ? Color(red: 0/255, green: 160/255, blue: 176/255)
                                    : Color(.systemGray6)
                            )
                        )
                        .foregroundColor(selected ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - List

    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                topThreeCard
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                ForEach(Array(entries.dropFirst(min(3, entries.count)).enumerated()), id: \.element.id) { idx, entry in
                    LeaderboardRowCard(
                        rank: idx + 4,
                        entry: entry,
                        metric: selectedMetric,
                        isCurrentUser: entry.uid == currentUserId
                    )
                    .padding(.horizontal, 16)
                }

                if let uid = currentUserId,
                   !entries.contains(where: { $0.uid == uid }) {
                    Text("You're not on this board yet — keep going!")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 16)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var topThreeCard: some View {
        let top3 = Array(entries.prefix(3))
        return HStack(alignment: .bottom, spacing: 12) {
            if top3.count >= 2 {
                podiumItem(entry: top3[1], rank: 2, height: 100)
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
            if !top3.isEmpty {
                podiumItem(entry: top3[0], rank: 1, height: 140)
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
            if top3.count >= 3 {
                podiumItem(entry: top3[2], rank: 3, height: 80)
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func podiumItem(entry: LeaderboardEntry, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                UserAvatarView(
                    photoUrl: entry.photoUrl,
                    displayName: entry.displayName,
                    size: 56
                )
                if rank <= 3 {
                    Text(rank == 1 ? "\u{1F451}" : (rank == 2 ? "\u{1F948}" : "\u{1F949}"))
                        .font(.title3)
                        .offset(y: -18)
                }
            }
            Text(entry.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .frame(maxWidth: 84)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(podiumColor(rank).opacity(0.25))
                .frame(height: height)
                .overlay(
                    VStack(spacing: 2) {
                        Text("#\(rank)")
                            .font(.headline.bold())
                        Text(selectedMetric.formatValue(entry.score))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                )
        }
        .frame(maxWidth: .infinity)
    }

    private func podiumColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .blue
        }
    }

    // MARK: - Empty / error

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No \(selectedMetric.title.lowercased()) leaders yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            NavigationLink(destination: MapScreen()) {
                Label("Start a Walk", systemImage: "figure.walk")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color(red: 0/255, green: 160/255, blue: 176/255))
                    )
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var emptyMessage: String {
        let scope = selectedPeriod == .weekly ? "this week" : "all-time"
        return "Be the first to top the \(selectedMetric.title.lowercased()) leaderboard \(scope)."
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Couldn't load leaderboard")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await reload() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Data load

    private func reload() async {
        isLoading = true
        loadError = nil

        // Read leaderboards/{period}_{metric}. The CF (TODO) writes:
        //   leaderboards/weekly_charity_points  → { entries: [...] }
        //   leaderboards/all_time_walk_distance → { entries: [...] }
        // We also accept the legacy single-metric layout
        // (leaderboards/points → { data: [...] }) for back-compat with the
        // existing dailyLeaderboard CF.
        let docId = "\(selectedPeriod.rawValue)_\(selectedMetric.rawValue)"
        let legacyId = selectedMetric.legacyDocId

        do {
            // Primary read: new layout.
            let primary = try await db.collection("leaderboards").document(docId).getDocument()
            if primary.exists, let parsed = parseEntries(primary.data()) {
                entries = parsed
                isLoading = false
                return
            }

            // Fallback: legacy single-metric layout for all-time / pawpoints.
            if selectedPeriod == .allTime, let legacyId = legacyId {
                let legacy = try await db.collection("leaderboards").document(legacyId).getDocument()
                if legacy.exists, let parsed = parseEntries(legacy.data()) {
                    entries = parsed
                    isLoading = false
                    return
                }
            }

            // Cold start — show empty state.
            entries = []
            isLoading = false
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    private func parseEntries(_ data: [String: Any]?) -> [LeaderboardEntry]? {
        guard let data = data else { return nil }
        // Accept either { entries: [...] } (new) or { data: [...] } (legacy).
        let raw: [[String: Any]]?
        if let arr = data["entries"] as? [[String: Any]] { raw = arr }
        else if let arr = data["data"] as? [[String: Any]] { raw = arr }
        else { raw = nil }

        guard let raw = raw else { return nil }

        var out: [LeaderboardEntry] = []
        for (idx, entry) in raw.enumerated() {
            let uid = (entry["uid"] as? String)
                ?? (entry["userId"] as? String)
                ?? UUID().uuidString
            let displayName = (entry["displayName"] as? String)
                ?? (entry["username"] as? String)
                ?? "Walker"
            let photoUrl = entry["photoUrl"] as? String
            let rank = (entry["rank"] as? Int) ?? (idx + 1)

            // The score field name varies by metric / CF version. Try the
            // explicit per-metric name first, then a generic `score`, then
            // the legacy `points` / `count` fields.
            let score: Double = (entry[selectedMetric.scoreFieldName] as? Double)
                ?? (entry[selectedMetric.scoreFieldName] as? Int).map(Double.init)
                ?? (entry["score"] as? Double)
                ?? (entry["score"] as? Int).map(Double.init)
                ?? (entry["points"] as? Double)
                ?? (entry["points"] as? Int).map(Double.init)
                ?? (entry["count"] as? Double)
                ?? (entry["count"] as? Int).map(Double.init)
                ?? 0

            out.append(LeaderboardEntry(
                uid: uid,
                displayName: displayName,
                photoUrl: photoUrl,
                score: score,
                rank: rank
            ))
        }
        return out
    }
}

// MARK: - Types

enum LeaderboardPeriod: String, CaseIterable {
    case weekly
    case allTime = "all_time"

    var title: String {
        switch self {
        case .weekly: return "This Week"
        case .allTime: return "All Time"
        }
    }
}

enum LeaderboardMetric: String, CaseIterable {
    case charityPoints = "charity_points"
    case walkDistance = "walk_distance"
    case streak = "streak"
    case friends = "friends"

    var title: String {
        switch self {
        case .charityPoints: return "Charity Points"
        case .walkDistance: return "Walk Distance"
        case .streak: return "Streak"
        case .friends: return "Friends"
        }
    }

    var iconSystemName: String {
        switch self {
        case .charityPoints: return "heart.fill"
        case .walkDistance: return "figure.walk"
        case .streak: return "flame.fill"
        case .friends: return "person.2.fill"
        }
    }

    /// Field name used inside each leaderboard entry for this metric's
    /// numeric value. Mirrors Android's per-metric score-field convention.
    var scoreFieldName: String {
        switch self {
        case .charityPoints: return "charityPoints"
        case .walkDistance: return "distanceMeters"
        case .streak: return "streakDays"
        case .friends: return "friendCount"
        }
    }

    /// Legacy single-metric doc id (the old `updateLeaderboards` CF only
    /// emits `points` / `contributors` / `reputation`). Lets us fall back
    /// when the new layout hasn't been deployed yet.
    var legacyDocId: String? {
        switch self {
        case .charityPoints: return "points"
        case .walkDistance: return nil
        case .streak: return nil
        case .friends: return nil
        }
    }

    func formatValue(_ value: Double) -> String {
        switch self {
        case .charityPoints:
            return "\(Int(value)) pts"
        case .walkDistance:
            return String(format: "%.1f km", value / 1000.0)
        case .streak:
            return "\(Int(value))d"
        case .friends:
            return "\(Int(value))"
        }
    }
}

struct LeaderboardEntry: Identifiable {
    let uid: String
    let displayName: String
    let photoUrl: String?
    let score: Double
    let rank: Int

    var id: String { uid }
}

// MARK: - Row card

private struct LeaderboardRowCard: View {
    let rank: Int
    let entry: LeaderboardEntry
    let metric: LeaderboardMetric
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCurrentUser
                          ? Color(red: 0/255, green: 160/255, blue: 176/255)
                          : Color(.systemGray5))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.caption.bold())
                    .foregroundColor(isCurrentUser ? .white : .primary)
            }

            UserAvatarView(
                photoUrl: entry.photoUrl,
                displayName: entry.displayName,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.subheadline)
                        .fontWeight(isCurrentUser ? .bold : .semibold)
                    if isCurrentUser {
                        Text("You")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.15))
                            )
                            .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                    }
                }
            }

            Spacer()

            Text(metric.formatValue(entry.score))
                .font(.subheadline.bold())
                .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser
                      ? Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.08)
                      : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser
                        ? Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.4)
                        : Color.clear,
                        lineWidth: 1)
        )
    }
}

struct LeaderboardScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LeaderboardScreen()
        }
    }
}
