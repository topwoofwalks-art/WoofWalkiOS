import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var selectedPost: Post?

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var listener: ListenerRegistration?

    init() { loadPosts() }

    func loadPosts() {
        isLoading = true
        listener = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    let nsError = error as NSError
                    // Firestore error code 9 = FAILED_PRECONDITION (missing index)
                    if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                        print("[Feed] Index missing for ordered query, falling back to client-side sort")
                        self.loadPostsUnsorted()
                    } else {
                        print("[Feed] Snapshot error: \(error.localizedDescription)")
                    }
                    return
                }

                self.posts = (snapshot?.documents ?? []).compactMap { try? $0.data(as: Post.self) }
            }
    }

    /// Fallback: fetch without orderBy and sort client-side when the descending index is missing.
    private func loadPostsUnsorted() {
        listener?.remove()
        listener = db.collection("posts")
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    print("[Feed] Fallback snapshot error: \(error.localizedDescription)")
                    return
                }

                let decoded = (snapshot?.documents ?? []).compactMap { try? $0.data(as: Post.self) }
                self.posts = decoded.sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }
            }
    }

    func refresh() {
        listener?.remove()
        loadPosts()
    }

    func toggleLike(_ post: Post) {
        guard let uid = auth.currentUser?.uid else { return }
        Task {
            if post.likedBy.contains(uid) {
                try? await db.collection("posts").document(post.id ?? "").updateData([
                    "likedBy": FieldValue.arrayRemove([uid]),
                    "likeCount": FieldValue.increment(Int64(-1))
                ])
            } else {
                try? await db.collection("posts").document(post.id ?? "").updateData([
                    "likedBy": FieldValue.arrayUnion([uid]),
                    "likeCount": FieldValue.increment(Int64(1))
                ])
            }
        }
    }

    func createPost(text: String, photoUrl: String?) {
        guard let uid = auth.currentUser?.uid else { return }
        Task {
            let userDoc = try? await db.collection("users").document(uid).getDocument()
            let userName = userDoc?.data()?["username"] as? String ?? "User"
            let userAvatar = userDoc?.data()?["photoUrl"] as? String

            let post = Post(
                id: UUID().uuidString,
                authorId: uid,
                authorName: userName,
                authorAvatar: userAvatar,
                type: "TEXT",
                text: text,
                createdAt: Timestamp(),
                commentCount: 0,
                photoUrl: photoUrl,
                likeCount: 0,
                likedBy: []
            )
            try? db.collection("posts").document(post.id ?? "").setData(from: post)
        }
    }

    deinit { listener?.remove() }
}
