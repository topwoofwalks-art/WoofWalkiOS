import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// iOS port of `app/src/main/java/com/woofwalk/ui/profile/CharityDetailScreen.kt`.
///
/// Lightweight per-charity landing page. Loads:
///   1. The `charities/{charityId}` doc (falls back to the in-app
///      `CharityOrg.supportedCharities` registry when Firestore has no
///      override doc — pre-launch we ship before the back-office editor
///      lands).
///   2. The aggregate total raised this month from
///      `charity_monthly/{YYYY-MM}.charityPoints.{charityId}` so a
///      first-time visitor sees real community momentum.
///   3. The monthly leaderboard of top contributors *for this charity*
///      (filtered client-side from the per-month user_contributions
///      subcollection, mirroring Android's
///      `getMonthlyLeaderboard(charityId:)`).
///
/// The "Make this my chosen charity" action calls
/// `CharityRepository.setSelectedCharity(_:)` — same method Android
/// invokes when the user picks from the picker.
struct CharityDetailScreen: View {
    let charityId: String

    @State private var charity: CharityOrg?
    @State private var mission: String = ""
    @State private var totalRaisedThisMonth: Int64 = 0
    @State private var leaderboard: [LeaderboardRowModel] = []
    @State private var leaderboardNames: [String: String] = [:]   // userId -> displayName
    @State private var leaderboardAvatars: [String: String] = [:] // userId -> photoUrl
    @State private var isLoading: Bool = true
    @State private var isSelectingCharity: Bool = false
    @State private var selectedCharityId: String
    @State private var errorBanner: String?

    init(charityId: String) {
        self.charityId = charityId
        _selectedCharityId = State(initialValue: CharityRepository.shared.getSelectedCharityId())
    }

    private var isChosenByMe: Bool { selectedCharityId == charityId }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroHeader

                if isLoading && totalRaisedThisMonth == 0 && leaderboard.isEmpty {
                    ProgressView()
                        .padding(.top, 24)
                } else {
                    raisedCard
                    selectionButton
                    leaderboardSection
                }

                if let errorBanner = errorBanner {
                    Text(errorBanner)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle(charity?.name ?? "Charity")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCharity()
            await loadMonthlyAggregate()
            await loadLeaderboard()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var heroHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.turquoise90)
                    .frame(width: 96, height: 96)
                Text(charity?.logoEmoji ?? "💛")
                    .font(.system(size: 56))
            }

            Text(charity?.name ?? "Charity")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if !mission.isEmpty {
                Text(mission)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var raisedCard: some View {
        VStack(spacing: 6) {
            Text("Community impact this month")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(totalRaisedThisMonth) pts")
                .font(.largeTitle.bold())
                .foregroundColor(.turquoise60)
            Text("Every 10 m walked = 1 point.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
    }

    private var selectionButton: some View {
        Button(action: chooseAsMyCharity) {
            HStack(spacing: 8) {
                if isSelectingCharity {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: isChosenByMe ? "checkmark.circle.fill" : "heart.fill")
                }
                Text(isChosenByMe ? "Your chosen charity" : "Make this my chosen charity")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(isChosenByMe ? Color.green : Color.turquoise60)
            )
        }
        .buttonStyle(.plain)
        .disabled(isChosenByMe || isSelectingCharity)
    }

    @ViewBuilder
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.orange)
                Text("Top supporters this month")
                    .font(.headline)
                Spacer()
            }

            if leaderboard.isEmpty {
                VStack(spacing: 6) {
                    Text("No supporters yet this month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Be the first — turn on charity walks in Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            } else {
                ForEach(Array(leaderboard.enumerated()), id: \.element.id) { idx, row in
                    leaderboardRow(rank: idx + 1, row: row)
                }
            }
        }
    }

    private func leaderboardRow(rank: Int, row: LeaderboardRowModel) -> some View {
        let displayName = leaderboardNames[row.userId] ?? "Walker"
        let isMe = Auth.auth().currentUser?.uid == row.userId
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(medalColor(rank: rank))
                    .frame(width: 28, height: 28)
                Text("\(rank)")
                    .font(.caption.bold())
                    .foregroundColor(rank <= 3 ? .black : .secondary)
            }
            UserAvatarView(
                photoUrl: leaderboardAvatars[row.userId],
                displayName: displayName,
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline.bold())
                if isMe {
                    Text("You")
                        .font(.caption2.bold())
                        .foregroundColor(.turquoise60)
                }
            }
            Spacer()
            Text("\(row.points) pts")
                .font(.subheadline.bold())
                .foregroundColor(.turquoise60)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isMe ? Color.turquoise90.opacity(0.6) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }

    private func medalColor(rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return Color(.systemGray5)
        }
    }

    // MARK: - Loaders

    private func loadCharity() async {
        // Always seed from the local registry so the screen never sits blank
        // while Firestore loads — gives instant logo + name + description
        // for the supported charities.
        if let local = CharityOrg.supportedCharities.first(where: { $0.id == charityId }) {
            await MainActor.run {
                self.charity = local
                if self.mission.isEmpty { self.mission = local.description }
            }
        }

        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("charities").document(charityId).getDocument()
            if doc.exists, let data = doc.data() {
                let name = (data["name"] as? String) ?? charity?.name ?? "Charity"
                let description = (data["description"] as? String) ?? mission
                let emoji = (data["logoEmoji"] as? String) ?? charity?.logoEmoji ?? "💛"
                await MainActor.run {
                    self.charity = CharityOrg(id: charityId, name: name, description: description, logoEmoji: emoji)
                    if let mission = data["missionStatement"] as? String, !mission.isEmpty {
                        self.mission = mission
                    } else if !description.isEmpty {
                        self.mission = description
                    }
                }
            }
        } catch {
            // Non-fatal — local fallback already populated.
        }
        await MainActor.run { isLoading = false }
    }

    private func loadMonthlyAggregate() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let yearMonth = formatter.string(from: Date())

        do {
            let snap = try await Firestore.firestore()
                .collection("charity_monthly").document(yearMonth)
                .getDocument()
            guard let data = snap.data() else { return }
            if let map = data["charityPoints"] as? [String: Any], let val = map[charityId] {
                let points: Int64
                if let n = val as? Int64 { points = n }
                else if let n = val as? Int { points = Int64(n) }
                else if let n = val as? Double { points = Int64(n) }
                else if let s = val as? String, let n = Int64(s) { points = n }
                else { points = 0 }
                await MainActor.run { totalRaisedThisMonth = points }
            }
        } catch {
            // Non-fatal — UI shows 0.
        }
    }

    private func loadLeaderboard() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let yearMonth = formatter.string(from: Date())

        do {
            // Mirror Android: pull the monthly user_contributions ranking
            // and filter to this charity client-side. With realistic month
            // sizes this is cheaper than a composite index.
            let snap = try await Firestore.firestore()
                .collection("charity_monthly").document(yearMonth)
                .collection("user_contributions")
                .order(by: "points", descending: true)
                .limit(to: 100)
                .getDocuments()

            var rows: [LeaderboardRowModel] = []
            for doc in snap.documents {
                let data = doc.data()
                let cid = data["charityId"] as? String ?? ""
                guard cid == charityId else { continue }
                let pts: Int64
                if let n = data["points"] as? Int64 { pts = n }
                else if let n = data["points"] as? Int { pts = Int64(n) }
                else if let n = data["points"] as? Double { pts = Int64(n) }
                else { pts = 0 }
                rows.append(LeaderboardRowModel(id: doc.documentID, userId: doc.documentID, points: pts))
                if rows.count >= 20 { break }
            }

            await MainActor.run { self.leaderboard = rows }
            await hydrateLeaderboardUsers(rows.map { $0.userId })
        } catch {
            // Non-fatal — UI shows empty state.
        }
    }

    private func hydrateLeaderboardUsers(_ userIds: [String]) async {
        guard !userIds.isEmpty else { return }
        let db = Firestore.firestore()
        // whereIn caps at 30 — chunk to be safe with our 20-row limit too.
        let chunks = stride(from: 0, to: userIds.count, by: 30).map {
            Array(userIds[$0..<min($0 + 30, userIds.count)])
        }
        var names: [String: String] = [:]
        var avatars: [String: String] = [:]
        for chunk in chunks {
            do {
                let snap = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in snap.documents {
                    let data = doc.data()
                    let display = (data["displayName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                        ?? (data["username"] as? String)
                        ?? "Walker"
                    names[doc.documentID] = display
                    if let url = data["photoUrl"] as? String, !url.isEmpty {
                        avatars[doc.documentID] = url
                    }
                }
            } catch {
                continue
            }
        }
        await MainActor.run {
            self.leaderboardNames.merge(names) { _, new in new }
            self.leaderboardAvatars.merge(avatars) { _, new in new }
        }
    }

    // MARK: - Selection

    private func chooseAsMyCharity() {
        guard !isChosenByMe, !isSelectingCharity else { return }
        isSelectingCharity = true
        Task {
            do {
                try await CharityRepository.shared.setSelectedCharity(charityId)
                await MainActor.run {
                    selectedCharityId = charityId
                    isSelectingCharity = false
                }
            } catch {
                await MainActor.run {
                    errorBanner = "Couldn't save your choice: \(error.localizedDescription)"
                    isSelectingCharity = false
                }
            }
        }
    }
}

// MARK: - Models

private struct LeaderboardRowModel: Identifiable {
    let id: String
    let userId: String
    let points: Int64
}
