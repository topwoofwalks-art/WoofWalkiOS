import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommunityFeedTab: View {
    let communityId: String
    @StateObject private var viewModel: CommunityFeedViewModel
    @State private var showCreatePost = false

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: CommunityFeedViewModel(communityId: communityId))
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView()
            } else if viewModel.posts.isEmpty {
                feedEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Pinned posts
                        if !viewModel.pinnedPosts.isEmpty {
                            Section {
                                ForEach(viewModel.pinnedPosts) { post in
                                    FeedPostCard(post: post, isPinned: true, brandColor: brandColor) {
                                        Task { await viewModel.toggleReaction(postId: post.id) }
                                    }
                                }
                            } header: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pin.fill")
                                        .font(.caption2)
                                    Text("Pinned")
                                        .font(.caption.bold())
                                }
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            }
                        }

                        // Recent posts
                        ForEach(viewModel.recentPosts) { post in
                            FeedPostCard(post: post, isPinned: false, brandColor: brandColor) {
                                Task { await viewModel.toggleReaction(postId: post.id) }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showCreatePost = true }) {
                Image(systemName: "square.and.pencil")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(brandColor))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
            .padding(16)
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostSheet(communityId: communityId)
        }
    }

    private var feedEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("No Posts Yet")
                .font(.title3.bold())
            Text("Be the first to share something with the community!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: { showCreatePost = true }) {
                Label("Create Post", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(brandColor))
            }
            .padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Post Model

struct CommunityPost: Identifiable {
    let id: String
    let authorId: String
    let authorName: String
    let authorPhotoUrl: String?
    let content: String
    let imageUrl: String?
    let isPinned: Bool
    let reactionCount: Int
    let commentCount: Int
    let hasReacted: Bool
    let createdAt: Date
}

// MARK: - Post Card

struct FeedPostCard: View {
    let post: CommunityPost
    let isPinned: Bool
    let brandColor: Color
    let onReact: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Author row
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.authorName)
                        .font(.subheadline.bold())
                    Text(timeAgo(post.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Content
            Text(post.content)
                .font(.subheadline)

            // Image placeholder
            if post.imageUrl != nil {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.secondary.opacity(0.3))
                    )
            }

            // Reactions bar
            HStack(spacing: 16) {
                Button(action: onReact) {
                    HStack(spacing: 4) {
                        Image(systemName: post.hasReacted ? "heart.fill" : "heart")
                            .foregroundColor(post.hasReacted ? .red : .secondary)
                        Text("\(post.reactionCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.secondary)
                    Text("\(post.commentCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    // Share action placeholder
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .font(.subheadline)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
        .padding(.horizontal, 16)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Create Post Sheet

struct CreatePostSheet: View {
    let communityId: String
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var isPosting = false

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $content)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 16)

                HStack(spacing: 16) {
                    Button { } label: {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                    Button { } label: {
                        Image(systemName: "camera")
                            .font(.title3)
                            .foregroundColor(brandColor)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        Task {
                            isPosting = true
                            await postContent()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
        }
    }

    private func postContent() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userName = Auth.auth().currentUser?.displayName ?? "Unknown"
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "authorId": userId,
            "authorName": userName,
            "content": content.trimmingCharacters(in: .whitespacesAndNewlines),
            "isPinned": false,
            "reactions": [String: Bool](),
            "reactionCount": 0,
            "commentCount": 0,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        do {
            try await db.collection("communities").document(communityId)
                .collection("posts").addDocument(data: data)
        } catch {
            print("Create post error: \(error.localizedDescription)")
        }
    }
}

// MARK: - ViewModel

@MainActor
class CommunityFeedViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var isLoading = false

    var pinnedPosts: [CommunityPost] { posts.filter { $0.isPinned } }
    var recentPosts: [CommunityPost] { posts.filter { !$0.isPinned } }

    private let communityId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let currentUserId: String

    init(communityId: String) {
        self.communityId = communityId
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadPosts()
    }

    func loadPosts() {
        isLoading = true
        listener = db.collection("communities").document(communityId)
            .collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Feed error: \(error.localizedDescription)")
                    return
                }
                self.posts = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    let reactions = data["reactions"] as? [String: Bool] ?? [:]
                    return CommunityPost(
                        id: doc.documentID,
                        authorId: data["authorId"] as? String ?? "",
                        authorName: data["authorName"] as? String ?? "Unknown",
                        authorPhotoUrl: data["authorPhotoUrl"] as? String,
                        content: data["content"] as? String ?? "",
                        imageUrl: data["imageUrl"] as? String,
                        isPinned: data["isPinned"] as? Bool ?? false,
                        reactionCount: data["reactionCount"] as? Int ?? reactions.count,
                        commentCount: data["commentCount"] as? Int ?? 0,
                        hasReacted: reactions[self.currentUserId] == true,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }

    func toggleReaction(postId: String) async {
        guard !currentUserId.isEmpty else { return }
        let ref = db.collection("communities").document(communityId)
            .collection("posts").document(postId)
        let hasReacted = posts.first(where: { $0.id == postId })?.hasReacted ?? false
        do {
            if hasReacted {
                try await ref.updateData([
                    "reactions.\(currentUserId)": FieldValue.delete(),
                    "reactionCount": FieldValue.increment(Int64(-1)),
                ])
            } else {
                try await ref.updateData([
                    "reactions.\(currentUserId)": true,
                    "reactionCount": FieldValue.increment(Int64(1)),
                ])
            }
        } catch {
            print("Reaction error: \(error.localizedDescription)")
        }
    }

    deinit { listener?.remove() }
}
