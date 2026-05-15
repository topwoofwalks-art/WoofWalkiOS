import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Per-photo comments for a multi-image feed post.
///
/// Mirrors `ui/feed/PhotoCommentSheet.kt` — the same Firestore path
/// (`posts/{postId}/photo_comments/{commentId}`) with `photoIndex` scoping
/// the visible subset. The classic post-level comments live alongside this
/// in `posts/{postId}/comments` and aren't touched here.
struct PhotoCommentSheet: View {
    let post: Post
    let photoIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [PhotoComment] = []
    @State private var commentText: String = ""
    @State private var isSending: Bool = false
    @State private var loadError: String?
    @State private var listener: ListenerRegistration?

    private let db = Firestore.firestore()
    private var postId: String? { post.id }

    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    private var currentUserName: String { Auth.auth().currentUser?.displayName ?? "You" }
    private var currentUserAvatar: String? { Auth.auth().currentUser?.photoURL?.absoluteString }

    /// URL for the photo we're commenting on. Falls back to the legacy
    /// single `photoUrl` if the post uses the older shape and the index is 0.
    private var photoUrl: String? {
        if let media = post.media, photoIndex >= 0, photoIndex < media.count {
            return media[photoIndex].url
        }
        if photoIndex == 0 { return post.photoUrl }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                photoHeader
                Divider()
                if let err = loadError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                commentsList
                Divider()
                inputBar
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var photoHeader: some View {
        if let urlStr = photoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }

    private var commentsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Comments (\(comments.count))")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                if comments.isEmpty {
                    Text("No comments yet. Be the first!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(comments) { comment in
                        commentRow(comment)
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func commentRow(_ comment: PhotoComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(for: comment)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(comment.userName.isEmpty ? "Anonymous" : comment.userName)
                        .font(.caption.bold())
                    Text(comment.text)
                        .font(.subheadline)
                }
                HStack(spacing: 12) {
                    Text(relativeTime(ms: comment.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if comment.likes > 0 {
                        Text("\(comment.likes) like\(comment.likes == 1 ? "" : "s")")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer(minLength: 8)
            Button {
                toggleLike(comment)
            } label: {
                let liked = comment.likedBy.contains(currentUserId)
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundColor(liked ? .red : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func avatar(for comment: PhotoComment) -> some View {
        if let urlStr = comment.userAvatar, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(.secondary.opacity(0.4))
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Add a comment...", text: $commentText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .disabled(isSending)

            Button {
                Task { await sendComment() }
            } label: {
                if isSending {
                    ProgressView()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22))
                        .foregroundColor(canSend ? .accentColor : .secondary.opacity(0.4))
                }
            }
            .disabled(!canSend || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var canSend: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Firestore

    /// Live-listen to comments scoped by `photoIndex`. Sorted oldest-first
    /// for IG-style threading.
    private func startListening() {
        guard let postId else { return }
        stopListening()
        listener = db.collection("posts").document(postId).collection("photo_comments")
            .whereField("photoIndex", isEqualTo: photoIndex)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    // Permission-denied surfaces here on signed-out users —
                    // keep noise out of release logs but bubble for debug.
                    print("[PhotoCommentSheet] listen error: \(error.localizedDescription)")
                    loadError = error.localizedDescription
                    return
                }
                let docs = snapshot?.documents ?? []
                self.comments = docs.compactMap { doc in
                    var c = try? doc.data(as: PhotoComment.self)
                    if c?.id.isEmpty ?? true { c?.id = doc.documentID }
                    return c
                }
            }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func sendComment() async {
        guard let postId, canSend else { return }
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        defer { isSending = false }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let comment = PhotoComment(
            postId: postId,
            photoIndex: photoIndex,
            userId: currentUserId,
            userName: currentUserName,
            userAvatar: currentUserAvatar,
            text: text,
            timestamp: now,
            likes: 0,
            likedBy: []
        )
        do {
            _ = try db.collection("posts").document(postId).collection("photo_comments")
                .addDocument(from: comment)
            commentText = ""
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func toggleLike(_ comment: PhotoComment) {
        guard let postId else { return }
        let ref = db.collection("posts").document(postId).collection("photo_comments").document(comment.id)
        let uid = currentUserId
        guard !uid.isEmpty else { return }
        if comment.likedBy.contains(uid) {
            ref.updateData([
                "likedBy": FieldValue.arrayRemove([uid]),
                "likes": FieldValue.increment(Int64(-1))
            ])
        } else {
            ref.updateData([
                "likedBy": FieldValue.arrayUnion([uid]),
                "likes": FieldValue.increment(Int64(1))
            ])
        }
    }

    // MARK: - Helpers

    private func relativeTime(ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
