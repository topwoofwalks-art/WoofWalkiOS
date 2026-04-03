import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class CommunityPostRepository {
    static let shared = CommunityPostRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    private var postsListener: ListenerRegistration?
    private var commentsListener: ListenerRegistration?

    // MARK: - Posts (realtime)

    /// Listen to posts in a community, optionally filtered by type. Returns a Combine publisher.
    func getPosts(communityId: String, type: String? = nil) -> AnyPublisher<[CommunityPost], Never> {
        let subject = CurrentValueSubject<[CommunityPost], Never>([])

        postsListener?.remove()

        var query: Query = db.collection("communities").document(communityId)
            .collection("posts")
            .whereField("isDeleted", isEqualTo: false)

        if let type = type {
            query = query.whereField("type", isEqualTo: type)
        }

        query = query.order(by: "createdAt", descending: true)
            .limit(to: 50)

        postsListener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                print("[CommunityPostRepository] Snapshot error: \(error.localizedDescription)")
                subject.send([])
                return
            }

            let posts = (snapshot?.documents ?? []).compactMap { doc -> CommunityPost? in
                var post = try? doc.data(as: CommunityPost.self)
                post?.id = doc.documentID
                return post
            }

            // Pinned posts first, then by date
            let sorted = posts.sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
                return a.createdAt > b.createdAt
            }

            subject.send(sorted)
        }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Post CRUD

    /// Create a new post in a community.
    func createPost(communityId: String, post: CommunityPost) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityPostRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let userName = auth.currentUser?.displayName ?? "Anonymous"
        let userPhoto = auth.currentUser?.photoURL?.absoluteString

        var data = post
        data.communityId = communityId
        data.authorId = uid
        data.authorName = userName
        data.authorPhotoUrl = userPhoto
        data.createdAt = Date().timeIntervalSince1970 * 1000
        data.updatedAt = Date().timeIntervalSince1970 * 1000

        let postsRef = db.collection("communities").document(communityId).collection("posts")
        try postsRef.addDocument(from: data)

        // Increment community post count
        try await db.collection("communities").document(communityId).updateData([
            "postCount": FieldValue.increment(Int64(1)),
            "updatedAt": Date().timeIntervalSince1970 * 1000
        ])

        print("[CommunityPostRepository] Post created in \(communityId)")
    }

    /// Delete a post (soft delete by setting isDeleted flag).
    func deletePost(communityId: String, postId: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityPostRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let postRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)
        let postDoc = try await postRef.getDocument()
        guard let post = try? postDoc.data(as: CommunityPost.self) else {
            throw NSError(domain: "CommunityPostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
        }

        // Allow author or community moderators to delete
        if post.authorId != uid {
            let memberDoc = try await db.collection("communities").document(communityId)
                .collection("members").document(uid).getDocument()
            guard let member = try? memberDoc.data(as: CommunityMember.self), member.canModerate() else {
                throw NSError(domain: "CommunityPostRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this post"])
            }
        }

        try await postRef.updateData([
            "isDeleted": true,
            "updatedAt": Date().timeIntervalSince1970 * 1000
        ])

        // Decrement community post count
        try await db.collection("communities").document(communityId).updateData([
            "postCount": FieldValue.increment(Int64(-1)),
            "updatedAt": Date().timeIntervalSince1970 * 1000
        ])

        print("[CommunityPostRepository] Post deleted: \(postId)")
    }

    // MARK: - Reactions

    /// Toggle a like reaction on a post. Adds user to likedBy if not present, removes if present.
    func toggleReaction(communityId: String, postId: String, reaction: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityPostRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let postRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)
        let postDoc = try await postRef.getDocument()
        guard let post = try? postDoc.data(as: CommunityPost.self) else {
            throw NSError(domain: "CommunityPostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
        }

        if post.likedBy.contains(uid) {
            try await postRef.updateData([
                "likedBy": FieldValue.arrayRemove([uid]),
                "likeCount": FieldValue.increment(Int64(-1))
            ])
        } else {
            try await postRef.updateData([
                "likedBy": FieldValue.arrayUnion([uid]),
                "likeCount": FieldValue.increment(Int64(1))
            ])
        }
    }

    /// Toggle pin status on a post. Caller must be a moderator.
    func togglePin(communityId: String, postId: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityPostRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let memberDoc = try await db.collection("communities").document(communityId)
            .collection("members").document(uid).getDocument()
        guard let member = try? memberDoc.data(as: CommunityMember.self), member.canModerate() else {
            throw NSError(domain: "CommunityPostRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to pin posts"])
        }

        let postRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)
        let postDoc = try await postRef.getDocument()
        guard let post = try? postDoc.data(as: CommunityPost.self) else {
            throw NSError(domain: "CommunityPostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
        }

        try await postRef.updateData([
            "isPinned": !post.isPinned,
            "updatedAt": Date().timeIntervalSince1970 * 1000
        ])

        print("[CommunityPostRepository] Toggled pin on post: \(postId)")
    }

    // MARK: - Comments (realtime)

    /// Listen to comments on a post. Returns a Combine publisher.
    func getComments(communityId: String, postId: String) -> AnyPublisher<[CommunityComment], Never> {
        let subject = CurrentValueSubject<[CommunityComment], Never>([])

        commentsListener?.remove()

        commentsListener = db.collection("communities").document(communityId)
            .collection("posts").document(postId)
            .collection("comments")
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("[CommunityPostRepository] Comments snapshot error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }

                let comments = (snapshot?.documents ?? []).compactMap { doc -> CommunityComment? in
                    var comment = try? doc.data(as: CommunityComment.self)
                    comment?.id = doc.documentID
                    return comment
                }
                subject.send(comments)
            }

        return subject.eraseToAnyPublisher()
    }

    /// Add a comment to a post.
    func addComment(communityId: String, postId: String, comment: CommunityComment) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityPostRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let userName = auth.currentUser?.displayName ?? "Anonymous"
        let userPhoto = auth.currentUser?.photoURL?.absoluteString

        var data = comment
        data.communityId = communityId
        data.postId = postId
        data.authorId = uid
        data.authorName = userName
        data.authorPhotoUrl = userPhoto
        data.createdAt = Date().timeIntervalSince1970 * 1000
        data.updatedAt = Date().timeIntervalSince1970 * 1000

        let commentsRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)
            .collection("comments")
        try commentsRef.addDocument(from: data)

        // Increment comment count on the post
        try await db.collection("communities").document(communityId)
            .collection("posts").document(postId)
            .updateData([
                "commentCount": FieldValue.increment(Int64(1))
            ])

        print("[CommunityPostRepository] Comment added to post \(postId)")
    }

    /// Delete a comment (soft delete).
    func deleteComment(communityId: String, postId: String, commentId: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityPostRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let commentRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)
            .collection("comments").document(commentId)
        let commentDoc = try await commentRef.getDocument()
        guard let comment = try? commentDoc.data(as: CommunityComment.self) else {
            throw NSError(domain: "CommunityPostRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Comment not found"])
        }

        if comment.authorId != uid {
            let memberDoc = try await db.collection("communities").document(communityId)
                .collection("members").document(uid).getDocument()
            guard let member = try? memberDoc.data(as: CommunityMember.self), member.canModerate() else {
                throw NSError(domain: "CommunityPostRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this comment"])
            }
        }

        try await commentRef.updateData([
            "isDeleted": true,
            "updatedAt": Date().timeIntervalSince1970 * 1000
        ])

        // Decrement comment count on the post
        try await db.collection("communities").document(communityId)
            .collection("posts").document(postId)
            .updateData([
                "commentCount": FieldValue.increment(Int64(-1))
            ])

        print("[CommunityPostRepository] Comment deleted: \(commentId)")
    }

    // MARK: - Content Reporting

    /// Report a piece of content (post, comment, or community).
    func reportContent(
        communityId: String,
        targetType: String,
        targetId: String,
        reason: String,
        details: String
    ) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityPostRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let userName = auth.currentUser?.displayName ?? "Anonymous"

        let reportData: [String: Any] = [
            "communityId": communityId,
            "targetType": targetType,
            "targetId": targetId,
            "reason": reason,
            "details": details,
            "reportedBy": uid,
            "reporterName": userName,
            "status": "PENDING",
            "createdAt": Date().timeIntervalSince1970 * 1000
        ]

        try await db.collection("communities").document(communityId)
            .collection("reports").addDocument(data: reportData)

        print("[CommunityPostRepository] Content reported: \(targetType)/\(targetId)")
    }

    // MARK: - Type-Specific Post CRUD

    /// Create an adoption listing post.
    func createAdoptionListing(communityId: String, title: String, content: String, mediaUrls: [String] = [], metadata: [String: String] = [:]) async throws {
        var post = CommunityPost(type: CommunityPostType.ADOPTION_LISTING.rawValue, title: title, content: content, mediaUrls: mediaUrls, metadata: metadata)
        try await createPost(communityId: communityId, post: post)
    }

    /// Create a walk schedule post.
    func createWalkSchedule(communityId: String, title: String, content: String, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil, metadata: [String: String] = [:]) async throws {
        var post = CommunityPost(
            type: CommunityPostType.WALK_SCHEDULE.rawValue,
            title: title,
            content: content,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            metadata: metadata
        )
        try await createPost(communityId: communityId, post: post)
    }

    /// Create a puppy milestone post.
    func createMilestone(communityId: String, title: String, content: String, mediaUrls: [String] = [], linkedDogIds: [String] = [], metadata: [String: String] = [:]) async throws {
        var post = CommunityPost(
            type: CommunityPostType.PUPPY_MILESTONE.rawValue,
            title: title,
            content: content,
            mediaUrls: mediaUrls,
            linkedDogIds: linkedDogIds,
            metadata: metadata
        )
        try await createPost(communityId: communityId, post: post)
    }

    /// Create a training tip / progress post.
    func createTrainingProgress(communityId: String, title: String, content: String, mediaUrls: [String] = [], metadata: [String: String] = [:]) async throws {
        var post = CommunityPost(
            type: CommunityPostType.TRAINING_TIP.rawValue,
            title: title,
            content: content,
            mediaUrls: mediaUrls,
            metadata: metadata
        )
        try await createPost(communityId: communityId, post: post)
    }

    /// Create a breed alert post.
    func createBreedAlert(communityId: String, title: String, content: String, tags: [String] = [], metadata: [String: String] = [:]) async throws {
        var post = CommunityPost(
            type: CommunityPostType.BREED_ALERT.rawValue,
            title: title,
            content: content,
            tags: tags,
            metadata: metadata
        )
        try await createPost(communityId: communityId, post: post)
    }

    /// Create a destination review post.
    func createDestinationReview(communityId: String, title: String, content: String, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil, mediaUrls: [String] = [], metadata: [String: String] = [:]) async throws {
        var post = CommunityPost(
            type: CommunityPostType.DESTINATION_REVIEW.rawValue,
            title: title,
            content: content,
            mediaUrls: mediaUrls,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            metadata: metadata
        )
        try await createPost(communityId: communityId, post: post)
    }

    /// Create a diet plan post.
    func createDietPlan(communityId: String, title: String, content: String, linkedDogIds: [String] = [], metadata: [String: String] = [:]) async throws {
        var post = CommunityPost(
            type: CommunityPostType.DIET_PLAN.rawValue,
            title: title,
            content: content,
            linkedDogIds: linkedDogIds,
            metadata: metadata
        )
        try await createPost(communityId: communityId, post: post)
    }

    /// Create a competition entry post.
    func createCompetitionEntry(communityId: String, title: String, content: String, mediaUrls: [String] = [], linkedDogIds: [String] = [], metadata: [String: String] = [:]) async throws {
        var post = CommunityPost(
            type: CommunityPostType.COMPETITION_ENTRY.rawValue,
            title: title,
            content: content,
            mediaUrls: mediaUrls,
            linkedDogIds: linkedDogIds,
            metadata: metadata
        )
        try await createPost(communityId: communityId, post: post)
    }

    /// Fetch posts of a specific type in a community (one-shot, not realtime).
    func fetchPosts(communityId: String, type: CommunityPostType) async throws -> [CommunityPost] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("posts")
            .whereField("isDeleted", isEqualTo: false)
            .whereField("type", isEqualTo: type.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
    }

    // MARK: - Cleanup

    func stopListening() {
        postsListener?.remove()
        postsListener = nil
        commentsListener?.remove()
        commentsListener = nil
    }

    deinit {
        postsListener?.remove()
        commentsListener?.remove()
    }
}
