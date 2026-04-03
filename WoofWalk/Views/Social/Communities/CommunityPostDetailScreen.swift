import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - View Model

@MainActor
class CommunityPostDetailViewModel: ObservableObject {
    @Published var post: CommunityPost?
    @Published var comments: [CommunityComment] = []
    @Published var replyingTo: CommunityComment?
    @Published var newCommentText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    let communityId: String
    let postId: String

    init(communityId: String, postId: String) {
        self.communityId = communityId
        self.postId = postId
    }

    var currentUserId: String? { auth.currentUser?.uid }

    // MARK: - Load

    func loadPost() async {
        isLoading = true
        do {
            let doc = try await db.collection("communities").document(communityId)
                .collection("posts").document(postId).getDocument()
            post = try? doc.data(as: CommunityPost.self)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func loadComments() async {
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts").document(postId)
                .collection("comments")
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: false)
                .limit(to: 100)
                .getDocuments()
            comments = snapshot.documents.compactMap { try? $0.data(as: CommunityComment.self) }
        } catch {
            // Fallback without compound query
            let snapshot = try? await db.collection("communities").document(communityId)
                .collection("posts").document(postId)
                .collection("comments")
                .limit(to: 100)
                .getDocuments()
            comments = (snapshot?.documents ?? []).compactMap { try? $0.data(as: CommunityComment.self) }
                .filter { !$0.isDeleted }
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    // MARK: - Actions

    func sendComment() {
        guard let uid = auth.currentUser?.uid,
              !newCommentText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = newCommentText
        let parentId = replyingTo?.id
        newCommentText = ""
        replyingTo = nil

        Task {
            do {
                let userDoc = try await db.collection("users").document(uid).getDocument()
                let authorName = userDoc.data()?["username"] as? String ?? "User"
                let authorPhoto = userDoc.data()?["photoUrl"] as? String
                let now = Date().timeIntervalSince1970 * 1000

                let comment = CommunityComment(
                    postId: postId,
                    communityId: communityId,
                    authorId: uid,
                    authorName: authorName,
                    authorPhotoUrl: authorPhoto,
                    content: text.trimmingCharacters(in: .whitespaces),
                    parentCommentId: parentId,
                    createdAt: now,
                    updatedAt: now
                )

                try db.collection("communities").document(communityId)
                    .collection("posts").document(postId)
                    .collection("comments").addDocument(from: comment)

                // Increment comment count
                try await db.collection("communities").document(communityId)
                    .collection("posts").document(postId)
                    .updateData([
                        "commentCount": FieldValue.increment(Int64(1))
                    ])

                if let parentId = parentId {
                    try? await db.collection("communities").document(communityId)
                        .collection("posts").document(postId)
                        .collection("comments").document(parentId)
                        .updateData([
                            "replyCount": FieldValue.increment(Int64(1))
                        ])
                }

                await loadComments()

                if var p = post {
                    p.commentCount += 1
                    post = p
                }
            } catch {
                newCommentText = text
                errorMessage = "Failed to send comment"
            }
        }
    }

    func toggleLikePost() {
        guard let uid = auth.currentUser?.uid, var p = post else { return }

        let docRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)

        Task {
            if p.likedBy.contains(uid) {
                p.likedBy.removeAll { $0 == uid }
                p.likeCount = max(0, p.likeCount - 1)
                try? await docRef.updateData([
                    "likedBy": FieldValue.arrayRemove([uid]),
                    "likeCount": FieldValue.increment(Int64(-1))
                ])
            } else {
                p.likedBy.append(uid)
                p.likeCount += 1
                try? await docRef.updateData([
                    "likedBy": FieldValue.arrayUnion([uid]),
                    "likeCount": FieldValue.increment(Int64(1))
                ])
            }
            post = p
        }
    }

    func toggleLikeComment(_ comment: CommunityComment) {
        guard let uid = auth.currentUser?.uid, let commentId = comment.id else { return }

        let docRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)
            .collection("comments").document(commentId)

        Task {
            if comment.likedBy.contains(uid) {
                try? await docRef.updateData([
                    "likedBy": FieldValue.arrayRemove([uid]),
                    "likeCount": FieldValue.increment(Int64(-1))
                ])
            } else {
                try? await docRef.updateData([
                    "likedBy": FieldValue.arrayUnion([uid]),
                    "likeCount": FieldValue.increment(Int64(1))
                ])
            }
            await loadComments()
        }
    }

    func toggleBookmark() {
        guard let uid = auth.currentUser?.uid, var p = post else { return }

        let docRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)

        Task {
            if p.bookmarkedBy.contains(uid) {
                p.bookmarkedBy.removeAll { $0 == uid }
                try? await docRef.updateData([
                    "bookmarkedBy": FieldValue.arrayRemove([uid])
                ])
            } else {
                p.bookmarkedBy.append(uid)
                try? await docRef.updateData([
                    "bookmarkedBy": FieldValue.arrayUnion([uid])
                ])
            }
            post = p
        }
    }

    // MARK: - Threaded Comments

    var topLevelComments: [CommunityComment] {
        comments.filter { $0.parentCommentId == nil }
    }

    func replies(for comment: CommunityComment) -> [CommunityComment] {
        comments.filter { $0.parentCommentId == comment.id }
    }
}

// MARK: - View

struct CommunityPostDetailScreen: View {
    let communityId: String
    let postId: String

    @StateObject private var viewModel: CommunityPostDetailViewModel
    @FocusState private var isCommentFocused: Bool

    init(communityId: String, postId: String) {
        self.communityId = communityId
        self.postId = postId
        _viewModel = StateObject(wrappedValue: CommunityPostDetailViewModel(communityId: communityId, postId: postId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.post == nil {
                Spacer()
                ProgressView()
                Spacer()
            } else if let post = viewModel.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Post content
                        postContent(post)

                        Divider().padding(.vertical, 8)

                        // Reaction bar
                        reactionBar(post)

                        Divider().padding(.vertical, 8)

                        // Comments header
                        HStack {
                            Text("Comments")
                                .font(.headline)
                            Text("(\(post.commentCount))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)

                        // Threaded comments
                        if viewModel.comments.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("No comments yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Be the first to share your thoughts!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(viewModel.topLevelComments) { comment in
                                    CommentRow(
                                        comment: comment,
                                        replies: viewModel.replies(for: comment),
                                        currentUserId: viewModel.currentUserId,
                                        onLike: { viewModel.toggleLikeComment($0) },
                                        onReply: { viewModel.replyingTo = $0; isCommentFocused = true }
                                    )
                                }
                            }
                        }
                    }
                }
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task {
                            await viewModel.loadPost()
                            await viewModel.loadComments()
                        }
                    }
                    .foregroundColor(.turquoise60)
                }
                .padding()
                Spacer()
            }

            // Comment input
            commentInput
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPost()
            await viewModel.loadComments()
        }
    }

    // MARK: - Post Content

    private func postContent(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author header
            HStack(spacing: 10) {
                Circle().fill(Color.neutral90).frame(width: 44, height: 44)
                    .overlay {
                        if let url = post.authorPhotoUrl, let imgUrl = URL(string: url) {
                            AsyncImage(url: imgUrl) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                                .clipShape(Circle())
                        } else {
                            Text(String(post.authorName.prefix(1)))
                                .font(.headline)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.subheadline.bold())
                    HStack(spacing: 6) {
                        Text(formatDate(post.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if post.isPinned {
                            Label("Pinned", systemImage: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        if post.isEdited {
                            Text("(edited)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()

                // Post type badge
                Text(post.getPostType().rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.turquoise90))
                    .foregroundColor(.turquoise30)
            }

            // Title
            if !post.title.isEmpty {
                Text(post.title)
                    .font(.title3.bold())
            }

            // Content
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.body)
            }

            // Media
            if !post.mediaUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(post.mediaUrls, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.neutral90)
                                }
                                .frame(width: post.mediaUrls.count == 1 ? nil : 280, height: 200)
                                .frame(maxWidth: post.mediaUrls.count == 1 ? .infinity : nil)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }

            // Poll options
            if post.isPoll() {
                pollView(post)
            }

            // Tags
            if !post.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color(.systemGray6)))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Poll View

    private func pollView(_ post: CommunityPost) -> some View {
        let totalVotes = post.pollOptions.reduce(0) { $0 + $1.voteCount }
        let hasVoted = post.pollOptions.contains { $0.votedBy.contains(viewModel.currentUserId ?? "") }
        let expired = post.isPollExpired()

        return VStack(spacing: 8) {
            ForEach(post.pollOptions) { option in
                let percent = totalVotes > 0 ? Double(option.voteCount) / Double(totalVotes) : 0

                HStack {
                    Text(option.text)
                        .font(.subheadline)
                    Spacer()
                    if hasVoted || expired {
                        Text("\(Int(percent * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.turquoise90.opacity(0.3))
                            .frame(width: (hasVoted || expired) ? geo.size.width * percent : 0)
                    }
                )
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
            }

            HStack {
                Text("\(totalVotes) vote\(totalVotes == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if expired {
                    Text("Poll ended")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Reaction Bar

    private func reactionBar(_ post: CommunityPost) -> some View {
        let isLiked = post.isLikedBy(userId: viewModel.currentUserId ?? "")
        let isBookmarked = post.isBookmarkedBy(userId: viewModel.currentUserId ?? "")

        return HStack(spacing: 20) {
            Button {
                viewModel.toggleLikePost()
            } label: {
                Label("\(post.likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                    .font(.subheadline)
                    .foregroundColor(isLiked ? .red : .secondary)
            }

            Button {
                isCommentFocused = true
            } label: {
                Label("\(post.commentCount)", systemImage: "bubble.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                viewModel.toggleBookmark()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.subheadline)
                    .foregroundColor(isBookmarked ? .turquoise60 : .secondary)
            }

            Spacer()

            Button {
                // Share action
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Comment Input

    private var commentInput: some View {
        VStack(spacing: 0) {
            if let replyTo = viewModel.replyingTo {
                HStack {
                    Text("Replying to \(replyTo.authorName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        viewModel.replyingTo = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 6)
            }

            Divider()

            HStack(spacing: 10) {
                TextField(viewModel.replyingTo != nil ? "Write a reply..." : "Add a comment...",
                          text: $viewModel.newCommentText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isCommentFocused)

                Button {
                    viewModel.sendComment()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.turquoise60)
                }
                .disabled(viewModel.newCommentText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: CommunityComment
    let replies: [CommunityComment]
    let currentUserId: String?
    let onLike: (CommunityComment) -> Void
    let onReply: (CommunityComment) -> Void

    @State private var showReplies = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            commentBody(comment, isReply: false)

            // Replies
            if !replies.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showReplies.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showReplies ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                        Text("\(replies.count) repl\(replies.count == 1 ? "y" : "ies")")
                            .font(.caption)
                    }
                    .foregroundColor(.turquoise60)
                    .padding(.leading, 52)
                    .padding(.vertical, 4)
                }

                if showReplies {
                    ForEach(replies) { reply in
                        commentBody(reply, isReply: true)
                            .padding(.leading, 40)
                    }
                }
            }

            Divider()
                .padding(.leading, 52)
        }
    }

    private func commentBody(_ comment: CommunityComment, isReply: Bool) -> some View {
        let isLiked = comment.isLikedBy(userId: currentUserId ?? "")

        return HStack(alignment: .top, spacing: 10) {
            Circle().fill(Color.neutral90).frame(width: isReply ? 28 : 32, height: isReply ? 28 : 32)
                .overlay {
                    if let url = comment.authorPhotoUrl, let imgUrl = URL(string: url) {
                        AsyncImage(url: imgUrl) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                            .clipShape(Circle())
                    } else {
                        Text(String(comment.authorName.prefix(1)))
                            .font(isReply ? .caption2 : .caption)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(.caption.bold())
                    Text(formatCommentDate(comment.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(comment.content)
                    .font(.subheadline)

                // Actions
                HStack(spacing: 16) {
                    Button {
                        onLike(comment)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount)")
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(isLiked ? .red : .secondary)
                    }

                    if !isReply {
                        Button {
                            onReply(comment)
                        } label: {
                            Text("Reply")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func formatCommentDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
