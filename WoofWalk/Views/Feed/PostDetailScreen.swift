import SwiftUI
import FirebaseFirestore

struct PostDetailScreen: View {
    let post: Post
    @State private var comments: [PostComment] = []
    @State private var newComment = ""

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    WalkPostCard(post: post, onLike: {}, onComment: {}, onShare: {})
                        .padding()

                    Divider()

                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(comment.authorName).font(.caption.bold())
                                    Spacer()
                                    if let date = comment.createdAt?.dateValue() {
                                        Text(FormatUtils.formatRelativeTime(date)).font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                Text(comment.text).font(.body)
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Divider()
                HStack {
                    TextField("Add comment...", text: $newComment)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") { sendComment() }
                        .disabled(newComment.isEmpty)
                        .foregroundColor(.turquoise60)
                }
                .padding()
            }
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadComments() }
        }
    }

    private func loadComments() async {
        let snapshot = try? await db.collection("posts").document(post.id).collection("comments")
            .order(by: "createdAt", descending: false).getDocuments()
        comments = (snapshot?.documents ?? []).compactMap { try? $0.data(as: PostComment.self) }
    }

    private func sendComment() {
        guard !newComment.isEmpty else { return }
        let comment = PostComment(postId: post.id, authorId: "", authorName: "You", text: newComment, createdAt: Timestamp())
        try? db.collection("posts").document(post.id).collection("comments").addDocument(from: comment)
        comments.append(comment)
        newComment = ""
    }
}
