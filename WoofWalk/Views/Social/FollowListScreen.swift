import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// iOS port of `app/src/main/java/com/woofwalk/ui/profile/FollowListScreen.kt`.
///
/// Renders the list of users following / followed by `userId`. Storage
/// model mirrors Android exactly (single top-level `followers` collection,
/// composite doc id `<followerId>_<followingId>`):
///
///   followers/{followerId_followingId}
///     followerId:  uid of the user doing the following
///     followingId: uid of the user being followed
///     createdAt:   serverTimestamp
///
/// `type` is "followers" (users following this profile) or "following"
/// (users this profile is following). This is the same surface RouteDestination
/// already wires via `.followList(userId:, type:)`.
struct FollowListScreen: View {
    let userId: String
    let type: String   // "followers" or "following"

    @State private var users: [UserProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var followingSet: Set<String> = []   // who *I* follow — for action button state

    private var currentUid: String? { Auth.auth().currentUser?.uid }
    private var isFollowersTab: Bool { type.lowercased() == "followers" }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage, users.isEmpty {
                emptyState(title: "Couldn't load", body: errorMessage)
            } else if users.isEmpty {
                emptyState(
                    title: isFollowersTab ? "No followers yet" : "Not following anyone yet",
                    body: isFollowersTab
                        ? "When someone follows this profile, they'll appear here."
                        : "Profiles this user follows will appear here."
                )
            } else {
                List {
                    ForEach(users) { user in
                        FollowListRow(
                            user: user,
                            isCurrentUser: currentUid == user.id,
                            isFollowedByMe: followingSet.contains(user.id ?? ""),
                            onToggleFollow: { toggleFollow(for: user) }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(isFollowersTab ? "Followers" : "Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadList()
            await loadMyFollowingSet()
        }
    }

    @ViewBuilder
    private func emptyState(title: String, body: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Firestore reads

    private func loadList() async {
        let db = Firestore.firestore()
        do {
            // Mirror Android `UserRepository.getFollowers` / `getFollowing`:
            // 1) query `followers` collection by the appropriate side
            // 2) hydrate the matching user docs (chunks of 30 for whereIn)
            let query: Query = {
                if isFollowersTab {
                    return db.collection("followers").whereField("followingId", isEqualTo: userId)
                } else {
                    return db.collection("followers").whereField("followerId", isEqualTo: userId)
                }
            }()

            let snap = try await query.getDocuments()
            let idField = isFollowersTab ? "followerId" : "followingId"
            let ids: [String] = snap.documents.compactMap { $0.get(idField) as? String }

            guard !ids.isEmpty else {
                await MainActor.run {
                    self.users = []
                    self.isLoading = false
                }
                return
            }

            // `whereField:in:` is capped at 30 values per query; chunk to match
            // Android's `chunked(30)`.
            var hydrated: [UserProfile] = []
            for chunk in ids.chunked(into: 30) {
                let userSnap = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                for doc in userSnap.documents {
                    if var profile = try? doc.data(as: UserProfile.self) {
                        if profile.id == nil { profile.id = doc.documentID }
                        hydrated.append(profile)
                    }
                }
            }

            // Preserve the original follow-order — Firestore `whereField:in:`
            // returns documents in undefined order, so we re-key by id.
            let byId = Dictionary(uniqueKeysWithValues: hydrated.compactMap { profile -> (String, UserProfile)? in
                guard let id = profile.id else { return nil }
                return (id, profile)
            })
            let ordered = ids.compactMap { byId[$0] }

            await MainActor.run {
                self.users = ordered
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Pull the set of users *the current user* follows so each row can
    /// render the right Follow / Unfollow state.
    private func loadMyFollowingSet() async {
        guard let me = currentUid else { return }
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("followers")
                .whereField("followerId", isEqualTo: me)
                .getDocuments()
            let ids = snap.documents.compactMap { $0.get("followingId") as? String }
            await MainActor.run { self.followingSet = Set(ids) }
        } catch {
            // Silent — the rows just default to "Follow" if we can't tell.
        }
    }

    // MARK: - Follow/unfollow

    private func toggleFollow(for user: UserProfile) {
        guard let me = currentUid, let targetId = user.id, me != targetId else { return }
        let db = Firestore.firestore()
        let docId = "\(me)_\(targetId)"
        let ref = db.collection("followers").document(docId)
        let wasFollowing = followingSet.contains(targetId)

        // Optimistic flip.
        if wasFollowing {
            followingSet.remove(targetId)
        } else {
            followingSet.insert(targetId)
        }

        Task {
            do {
                if wasFollowing {
                    try await ref.delete()
                } else {
                    try await ref.setData([
                        "followerId": me,
                        "followingId": targetId,
                        "createdAt": FieldValue.serverTimestamp()
                    ])
                }
            } catch {
                // Roll back the optimistic flip on failure.
                await MainActor.run {
                    if wasFollowing {
                        followingSet.insert(targetId)
                    } else {
                        followingSet.remove(targetId)
                    }
                }
            }
        }
    }
}

private struct FollowListRow: View {
    let user: UserProfile
    let isCurrentUser: Bool
    let isFollowedByMe: Bool
    let onToggleFollow: () -> Void

    @StateObject private var navigator = AppNavigator.shared

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if let id = user.id, !isCurrentUser {
                    navigator.navigate(to: .publicProfile(userId: id))
                }
            } label: {
                HStack(spacing: 12) {
                    UserAvatarView(
                        photoUrl: user.photoUrl,
                        displayName: displayName,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        if !user.bio.isEmpty {
                            Text(user.bio)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if !isCurrentUser {
                Button(action: onToggleFollow) {
                    Text(isFollowedByMe ? "Unfollow" : "Follow")
                        .font(.caption.bold())
                        .foregroundColor(isFollowedByMe ? .primary : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isFollowedByMe ? Color(.systemGray5) : Color.turquoise60)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        if let d = user.displayName, !d.isEmpty { return d }
        if !user.username.isEmpty { return user.username }
        return "User"
    }
}

// `chunked(into:)` is provided by the canonical Array extension at
// `Extensions/Array+Chunked.swift`. Do not re-declare it here.
