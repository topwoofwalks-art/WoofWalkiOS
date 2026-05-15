import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// 4-tab segment matching Android `FriendsScreen.kt`. Friends / Requests /
/// Suggested / Sent. Tag order is load-bearing because we drive the segmented
/// picker via raw values.
enum FriendsTab: Int, CaseIterable, Identifiable {
    case friends = 0
    case requests = 1
    case suggested = 2
    case sent = 3

    var id: Int { rawValue }
}

struct FriendsListScreen: View {
    @StateObject private var viewModel = FriendsListViewModel()
    @State private var selectedTab: FriendsTab = .friends
    @State private var showAddFriend = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 4-tab segment matches Android. Counts are surfaced inline on
            // Requests + Sent so the user can see at a glance whether they
            // have anything pending.
            Picker("", selection: $selectedTab) {
                Text(String(localized: "friends_segment_friends")).tag(FriendsTab.friends)
                Text(String(format: String(localized: "friends_segment_requests_format"), Int64(viewModel.pendingRequests.count))).tag(FriendsTab.requests)
                Text(String(localized: "friends_segment_suggested")).tag(FriendsTab.suggested)
                Text(String(format: String(localized: "friends_segment_sent_format"), Int64(viewModel.sentRequests.count))).tag(FriendsTab.sent)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                switch selectedTab {
                case .friends: friendsList
                case .requests: requestsList
                case .suggested: suggestedList
                case .sent: sentList
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showAddFriend = true }) {
                Image(systemName: "person.badge.plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color(red: 0/255, green: 160/255, blue: 176/255)))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
            .padding(16)
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet()
        }
        .onChange(of: selectedTab) { newTab in
            switch newTab {
            case .suggested: viewModel.loadSuggestedIfNeeded()
            case .sent: viewModel.loadSentIfNeeded()
            default: break
            }
        }
    }

    @ViewBuilder
    private var friendsList: some View {
        if viewModel.friends.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.3))
                Text(String(localized: "friends_empty_title"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(String(localized: "friends_empty_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(action: { showAddFriend = true }) {
                    Label(String(localized: "friends_add_friends_cta"), systemImage: "person.badge.plus")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color(red: 0/255, green: 160/255, blue: 176/255))
                        )
                }
                .padding(.top, 8)
                Spacer()
            }
        } else {
            List(viewModel.friends) { friend in
                FriendRow(friend: friend)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var requestsList: some View {
        if viewModel.pendingRequests.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.3))
                Text(String(localized: "friends_requests_empty_title"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(String(localized: "friends_requests_empty_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List(viewModel.pendingRequests) { request in
                FriendRequestRow(
                    request: request,
                    onAccept: { viewModel.acceptRequest(request) },
                    onDecline: { viewModel.declineRequest(request) }
                )
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var suggestedList: some View {
        if viewModel.isLoadingSuggested && viewModel.suggestedUsers.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.suggestedUsers.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.4))
                Text(String(localized: "friends_suggested_empty_title"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(String(localized: "friends_suggested_empty_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
        } else {
            List(viewModel.suggestedUsers) { suggestion in
                SuggestedUserRow(
                    suggestion: suggestion,
                    onAdd: { viewModel.sendRequest(toUserId: suggestion.id) }
                )
            }
            .listStyle(.plain)
            .refreshable { await viewModel.loadSuggested(force: true) }
        }
    }

    @ViewBuilder
    private var sentList: some View {
        if viewModel.isLoadingSent && viewModel.sentRequests.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.sentRequests.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.3))
                Text(String(localized: "friends_sent_empty_title"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(String(localized: "friends_sent_empty_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
        } else {
            List(viewModel.sentRequests) { request in
                SentRequestRow(
                    request: request,
                    onCancel: { viewModel.cancelSentRequest(request) }
                )
            }
            .listStyle(.plain)
        }
    }
}

struct FriendInfo: Identifiable {
    let id: String
    let displayName: String
    let photoUrl: String?
    let lastActive: Date?
}

struct FriendRequestInfo: Identifiable {
    let id: String
    let fromUserId: String
    let fromDisplayName: String
    let fromPhotoUrl: String?
    let requestedAt: Date?
}

struct FriendRow: View {
    let friend: FriendInfo

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay {
                    if let photoUrl = friend.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                        }
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.subheadline.bold())
                if let lastActive = friend.lastActive {
                    Text(String(format: String(localized: "friends_active_format"), FormatUtils.formatRelativeTime(lastActive)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "bubble.left.fill")
                    .font(.body)
                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
            }
        }
        .padding(.vertical, 2)
    }
}

struct FriendRequestRow: View {
    let request: FriendRequestInfo
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromDisplayName)
                    .font(.subheadline.bold())
                if let date = request.requestedAt {
                    Text(String(format: String(localized: "friends_requested_format"), FormatUtils.formatRelativeTime(date)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onDecline) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }

            Button(action: onAccept) {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(red: 0/255, green: 160/255, blue: 176/255)))
            }
        }
        .padding(.vertical, 2)
    }
}

/// Result row for the Suggested tab. Mirrors `SuggestedUser` in Android
/// `FriendRepository.getSuggestedUsers()` — id + display fields + the user's
/// city (used in the subtitle as a "you might live near each other" hint).
struct SuggestedUserInfo: Identifiable, Equatable {
    let id: String
    let displayName: String
    let username: String
    let photoUrl: String?
    let city: String?
    /// Set to true while the "Add friend" button is in-flight so the row
    /// can swap the icon for a ProgressView. State lives on the model
    /// (rather than the row) so the row stays stateless and the parent
    /// view-model can update it without an `@State` round-trip.
    var isSending: Bool = false
}

/// Outgoing friend request the current user has sent. Surfaced on the
/// Sent tab so they can cancel a request that's been sitting pending.
struct SentRequestInfo: Identifiable, Equatable {
    /// Canonical friendship doc id (`{loId}_{hiId}`).
    let id: String
    /// The user we sent the request TO.
    let toUserId: String
    let toDisplayName: String
    let toPhotoUrl: String?
    let createdAt: Date?
}

struct SuggestedUserRow: View {
    let suggestion: SuggestedUserInfo
    let onAdd: () -> Void
    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(brandColor.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay {
                    if let photoUrl = suggestion.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .foregroundColor(brandColor)
                        }
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(brandColor)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.displayName)
                    .font(.subheadline.bold())
                if let city = suggestion.city, !city.isEmpty {
                    Text(city)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if !suggestion.username.isEmpty {
                    Text("@\(suggestion.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if suggestion.isSending {
                ProgressView().frame(width: 32, height: 32)
            } else {
                Button(action: onAdd) {
                    Label(String(localized: "friends_add_button"), systemImage: "person.badge.plus")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(brandColor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SentRequestRow: View {
    let request: SentRequestInfo
    let onCancel: () -> Void
    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(brandColor.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay {
                    if let photoUrl = request.toPhotoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .foregroundColor(brandColor)
                        }
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(brandColor)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.toDisplayName)
                    .font(.subheadline.bold())
                if let date = request.createdAt {
                    Text(String(format: String(localized: "friends_sent_format"), FormatUtils.formatRelativeTime(date)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(String(localized: "friends_status_pending"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onCancel) {
                Text(String(localized: "action_cancel"))
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

@MainActor
class FriendsListViewModel: ObservableObject {
    @Published var friends: [FriendInfo] = []
    @Published var pendingRequests: [FriendRequestInfo] = []
    @Published var sentRequests: [SentRequestInfo] = []
    @Published var suggestedUsers: [SuggestedUserInfo] = []
    @Published var isLoading = false
    @Published var isLoadingSent = false
    @Published var isLoadingSuggested = false

    private let db = Firestore.firestore()
    private var friendsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    private var sentListener: ListenerRegistration?
    private var suggestedLoadedAt: Date = .distantPast
    private let suggestedCacheTTL: TimeInterval = 300  // 5 minutes
    private let userRepository = UserRepository()
    private let currentUserId: String

    init() {
        currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadFriends()
        loadRequests()
    }

    func loadFriends() {
        guard !currentUserId.isEmpty else { return }
        isLoading = true

        friendsListener = db.collection("friendships")
            .whereField("status", isEqualTo: "ACCEPTED")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Friends error: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                self.friends = docs.compactMap { doc in
                    let data = doc.data()
                    let userId1 = data["userId1"] as? String ?? ""
                    let userId2 = data["userId2"] as? String ?? ""
                    guard userId1 == self.currentUserId || userId2 == self.currentUserId else { return nil }
                    let friendId = userId1 == self.currentUserId ? userId2 : userId1
                    return FriendInfo(
                        id: friendId,
                        displayName: data["displayName_\(friendId)"] as? String ?? "Dog Walker",
                        photoUrl: data["photoUrl_\(friendId)"] as? String,
                        lastActive: nil
                    )
                }
            }
    }

    func loadRequests() {
        guard !currentUserId.isEmpty else { return }

        requestsListener = db.collection("friendships")
            .whereField("userId2", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "PENDING")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("Friend requests error: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                self.pendingRequests = docs.compactMap { doc in
                    let data = doc.data()
                    let fromId = data["userId1"] as? String ?? ""
                    return FriendRequestInfo(
                        id: doc.documentID,
                        fromUserId: fromId,
                        fromDisplayName: data["displayName_\(fromId)"] as? String ?? "Dog Walker",
                        fromPhotoUrl: data["photoUrl_\(fromId)"] as? String,
                        requestedAt: (data["createdAt"] as? Timestamp)?.dateValue()
                    )
                }
            }
    }

    func acceptRequest(_ request: FriendRequestInfo) {
        Task {
            try? await userRepository.acceptFriendRequest(friendshipId: request.id)
        }
    }

    func declineRequest(_ request: FriendRequestInfo) {
        Task {
            try? await userRepository.rejectFriendRequest(friendshipId: request.id)
        }
    }

    // MARK: - Sent (outgoing) requests

    /// One-shot lazy load — Sent tab is rarely opened, so we don't hold
    /// a listener for it like Friends/Requests do.
    func loadSentIfNeeded() {
        guard sentListener == nil else { return }
        loadSent()
    }

    private func loadSent() {
        guard !currentUserId.isEmpty else { return }
        isLoadingSent = true

        // Outgoing pending requests = friendship docs with status PENDING
        // where I'm the one who initiated (requestedBy == me).
        sentListener = db.collection("friendships")
            .whereField("requestedBy", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "PENDING")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoadingSent = false
                if let error {
                    print("[FriendsList] Sent requests error: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                // Pull display names from /users for each recipient.
                // Async fan-out — the snapshot publishes immediately with
                // placeholder display names, then we patch each row as
                // its profile resolves.
                let bareRows: [SentRequestInfo] = docs.compactMap { doc in
                    let data = doc.data()
                    let userId1 = data["userId1"] as? String ?? ""
                    let userId2 = data["userId2"] as? String ?? ""
                    let toUserId = userId1 == self.currentUserId ? userId2 : userId1
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                    return SentRequestInfo(
                        id: doc.documentID,
                        toUserId: toUserId,
                        toDisplayName: "Dog Walker",
                        toPhotoUrl: nil,
                        createdAt: createdAt
                    )
                }
                self.sentRequests = bareRows
                self.hydrateSentDisplayNames(for: bareRows)
            }
    }

    private func hydrateSentDisplayNames(for rows: [SentRequestInfo]) {
        Task { @MainActor in
            for row in rows {
                let toUserId = row.toUserId
                do {
                    let doc = try await db.collection("users").document(toUserId).getDocument()
                    guard let data = doc.data() else { continue }
                    let displayName = (data["displayName"] as? String)
                        ?? (data["username"] as? String)
                        ?? "Dog Walker"
                    let photoUrl = data["photoUrl"] as? String
                    if let idx = self.sentRequests.firstIndex(where: { $0.id == row.id }) {
                        self.sentRequests[idx] = SentRequestInfo(
                            id: row.id,
                            toUserId: toUserId,
                            toDisplayName: displayName,
                            toPhotoUrl: photoUrl,
                            createdAt: row.createdAt
                        )
                    }
                } catch {
                    // Non-fatal — row keeps its placeholder name.
                    print("[FriendsList] Failed to hydrate sent row \(toUserId): \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelSentRequest(_ request: SentRequestInfo) {
        Task {
            do {
                try await userRepository.cancelFriendRequest(friendshipId: request.id)
                // Optimistic local removal — the snapshot listener will
                // also drop it on the next tick.
                self.sentRequests.removeAll { $0.id == request.id }
            } catch {
                print("[FriendsList] Cancel sent request failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Suggested users

    func loadSuggestedIfNeeded() {
        let stale = Date().timeIntervalSince(suggestedLoadedAt) > suggestedCacheTTL
        guard suggestedUsers.isEmpty || stale else { return }
        Task { await loadSuggested(force: false) }
    }

    /// Suggested algorithm (simple-first port of Android
    /// `FriendRepository.getSuggestedUsers`):
    ///   * exclude self
    ///   * exclude anyone we have a friendship doc with (any status)
    ///   * exclude blocked users (either direction)
    ///   * exclude hideFromSearch
    ///   * surface 20 recent registrations, prefer same city as current
    ///     user if we know their city
    ///
    /// Over-fetches 3× the limit because some rows get filtered
    /// client-side (no point burning a composite index on a rare query).
    func loadSuggested(force: Bool) async {
        guard !currentUserId.isEmpty else { return }
        if isLoadingSuggested { return }
        isLoadingSuggested = true
        defer { isLoadingSuggested = false }

        // 1. Connected ids (any friendship doc in either direction).
        var connectedIds = Set<String>()
        var blockedIds = Set<String>()
        do {
            let side1 = try await db.collection("friendships")
                .whereField("userId1", isEqualTo: currentUserId)
                .getDocuments()
            for doc in side1.documents {
                if let id = doc.data()["userId2"] as? String { connectedIds.insert(id) }
                if (doc.data()["status"] as? String) == "BLOCKED",
                   let id = doc.data()["userId2"] as? String { blockedIds.insert(id) }
            }
            let side2 = try await db.collection("friendships")
                .whereField("userId2", isEqualTo: currentUserId)
                .getDocuments()
            for doc in side2.documents {
                if let id = doc.data()["userId1"] as? String { connectedIds.insert(id) }
                if (doc.data()["status"] as? String) == "BLOCKED",
                   let id = doc.data()["userId1"] as? String { blockedIds.insert(id) }
            }
        } catch {
            print("[FriendsList] Suggested: failed to fetch friendship graph: \(error.localizedDescription)")
        }

        // 2. Our own city (used to bias suggestions toward the same area).
        let myCity: String? = await {
            do {
                let doc = try await db.collection("users").document(currentUserId).getDocument()
                if let addr = doc.data()?["address"] as? [String: Any] {
                    return (addr["city"] as? String)?.lowercased()
                }
            } catch {
                print("[FriendsList] Suggested: failed to fetch own profile: \(error.localizedDescription)")
            }
            return nil
        }()

        // 3. Candidates page — over-fetch by 3×.
        let pageSize = 60
        var candidates: [(SuggestedUserInfo, isSameCity: Bool)] = []
        do {
            let snap = try await db.collection("users")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
                .getDocuments()
            for doc in snap.documents {
                let id = doc.documentID
                if id == currentUserId { continue }
                if connectedIds.contains(id) { continue }
                if blockedIds.contains(id) { continue }
                let data = doc.data()
                if (data["hideFromSearch"] as? Bool) == true { continue }
                let username = (data["username"] as? String) ?? ""
                if username.isEmpty { continue }
                let displayName = (data["displayName"] as? String) ?? username
                let photoUrl = data["photoUrl"] as? String
                let city = (data["address"] as? [String: Any])?["city"] as? String
                let sameCity = myCity != nil && city?.lowercased() == myCity
                candidates.append((
                    SuggestedUserInfo(
                        id: id,
                        displayName: displayName,
                        username: username,
                        photoUrl: photoUrl,
                        city: city,
                        isSending: false
                    ),
                    isSameCity: sameCity
                ))
            }
        } catch {
            print("[FriendsList] Suggested fetch failed: \(error.localizedDescription)")
        }

        // 4. Sort: same-city first, then by recency (already createdAt-desc
        //    from Firestore). Take top 20.
        let ordered = candidates
            .sorted { lhs, rhs in
                if lhs.isSameCity != rhs.isSameCity { return lhs.isSameCity }
                return false  // stable on equal city flag, preserves Firestore order
            }
            .prefix(20)
            .map { $0.0 }

        self.suggestedUsers = Array(ordered)
        self.suggestedLoadedAt = Date()
    }

    /// Send a request from the Suggested tab. Flips the row's spinner on,
    /// fires the canonical `UserRepository.sendFriendRequest`, then drops
    /// the row out of Suggested (it'll now show up under Sent).
    func sendRequest(toUserId: String) {
        guard let idx = suggestedUsers.firstIndex(where: { $0.id == toUserId }) else { return }
        suggestedUsers[idx].isSending = true

        Task {
            do {
                try await userRepository.sendFriendRequest(toUserId: toUserId)
                self.suggestedUsers.removeAll { $0.id == toUserId }
            } catch {
                if let i = self.suggestedUsers.firstIndex(where: { $0.id == toUserId }) {
                    self.suggestedUsers[i].isSending = false
                }
                print("[FriendsList] Suggested send-request failed: \(error.localizedDescription)")
            }
        }
    }

    deinit {
        friendsListener?.remove()
        requestsListener?.remove()
        sentListener?.remove()
    }
}

// MARK: - Add Friend Sheet (Search & Send Request)

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [SearchUserResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let db = Firestore.firestore()
    private let userRepository = UserRepository()
    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(String(localized: "friends_search_placeholder"), text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { performSearch() }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; searchResults = [] }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(String(localized: "friends_search_no_users"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(brandColor.opacity(0.3))
                        Text(String(localized: "friends_search_prompt"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(searchResults) { result in
                        SearchUserRow(
                            result: result,
                            onSendRequest: { sendRequest(to: result) }
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "friends_add_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "action_cancel")) { dismiss() }
                }
            }
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        isSearching = true
        errorMessage = nil

        let lowerQuery = query.lowercased()
        let endChar = lowerQuery + "\u{f8ff}"

        Task {
            do {
                var resultMap: [String: SearchUserResult] = [:]

                // Search by searchableUsername
                let usernameSnapshot = try await db.collection("users")
                    .order(by: "searchableUsername")
                    .start(at: [lowerQuery])
                    .end(at: [endChar])
                    .limit(to: 20)
                    .getDocuments()

                for doc in usernameSnapshot.documents {
                    guard doc.documentID != currentUserId else { continue }
                    if let user = try? doc.data(as: UserProfile.self) {
                        resultMap[doc.documentID] = SearchUserResult(
                            id: doc.documentID,
                            username: user.username,
                            displayName: user.displayName,
                            photoUrl: user.photoUrl,
                            status: nil,
                            isSending: false
                        )
                    }
                }

                // Load friendship statuses for results
                let keys = Array(resultMap.keys)
                for key in keys {
                    let statusResult = try await userRepository.getFriendshipStatus(userId: key)
                    resultMap[key]?.status = statusResult.status
                }

                let finalResults = Array(resultMap.values)
                await MainActor.run {
                    searchResults = finalResults
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = String(localized: "error_search_failed")
                    isSearching = false
                }
            }
        }
    }

    private func sendRequest(to result: SearchUserResult) {
        guard let index = searchResults.firstIndex(where: { $0.id == result.id }) else { return }
        searchResults[index].isSending = true

        Task {
            do {
                try await userRepository.sendFriendRequest(toUserId: result.id)
                await MainActor.run {
                    if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
                        searchResults[idx].status = .pending
                        searchResults[idx].isSending = false
                    }
                }
            } catch {
                await MainActor.run {
                    if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
                        searchResults[idx].isSending = false
                    }
                }
                print("Failed to send friend request: \(error.localizedDescription)")
            }
        }
    }
}

struct SearchUserResult: Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let photoUrl: String?
    var status: FriendStatus?
    var isSending: Bool
}

struct SearchUserRow: View {
    let result: SearchUserResult
    let onSendRequest: () -> Void
    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(brandColor.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    if let photoUrl = result.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .foregroundColor(brandColor)
                        }
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundColor(brandColor)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName ?? result.username)
                    .font(.subheadline.bold())
                if result.displayName != nil {
                    Text("@\(result.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            switch result.status {
            case .accepted:
                Label(String(localized: "friends_status_friends"), systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundColor(.green)

            case .pending:
                Text(String(localized: "friends_status_pending"))
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(16)

            case .blocked:
                EmptyView()

            case nil:
                if result.isSending {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Button(action: onSendRequest) {
                        Image(systemName: "person.badge.plus")
                            .font(.body.bold())
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(brandColor))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
