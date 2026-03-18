import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FriendsListScreen: View {
    @StateObject private var viewModel = FriendsListViewModel()
    @State private var selectedSegment = 0
    @State private var showAddFriend = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Segment control
            Picker("", selection: $selectedSegment) {
                Text("Friends").tag(0)
                Text("Requests (\(viewModel.pendingRequests.count))").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if selectedSegment == 0 {
                friendsList
            } else {
                requestsList
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
    }

    @ViewBuilder
    private var friendsList: some View {
        if viewModel.friends.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.3))
                Text("No Friends Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Add friends to see their walks and chat with them.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(action: { showAddFriend = true }) {
                    Label("Add Friends", systemImage: "person.badge.plus")
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
                Text("No Pending Requests")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Friend requests will appear here.")
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
                    Text("Active \(FormatUtils.formatRelativeTime(lastActive))")
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
                    Text("Requested \(FormatUtils.formatRelativeTime(date))")
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

@MainActor
class FriendsListViewModel: ObservableObject {
    @Published var friends: [FriendInfo] = []
    @Published var pendingRequests: [FriendRequestInfo] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var friendsListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
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
        let repo = UserRepository()
        Task {
            try? await repo.acceptFriendRequest(friendshipId: request.id)
        }
    }

    func declineRequest(_ request: FriendRequestInfo) {
        let repo = UserRepository()
        Task {
            try? await repo.rejectFriendRequest(friendshipId: request.id)
        }
    }

    deinit {
        friendsListener?.remove()
        requestsListener?.remove()
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
                    TextField("Search by username...", text: $searchText)
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
                        Text("No users found")
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
                        Text("Search for friends by username")
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
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
                for key in resultMap.keys {
                    let statusResult = try await userRepository.getFriendshipStatus(userId: key)
                    resultMap[key]?.status = statusResult.status
                }

                await MainActor.run {
                    searchResults = Array(resultMap.values)
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Search failed. Please try again."
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
                Label("Friends", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundColor(.green)

            case .pending:
                Text("Pending")
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
