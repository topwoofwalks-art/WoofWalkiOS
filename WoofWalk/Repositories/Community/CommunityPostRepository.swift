import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

/// Mirrors `data.repository.CommunityPostRepository` on Android. Owns CRUD
/// for posts + comments + typed reactions + bookmarks + polls + reporting.
final class CommunityPostRepository {
    static let shared = CommunityPostRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()

    private init() {}

    private var communitiesCollection: CollectionReference {
        db.collection("communities")
    }

    private func postsCollection(_ communityId: String) -> CollectionReference {
        communitiesCollection.document(communityId).collection("posts")
    }

    private func commentsCollection(_ communityId: String, _ postId: String) -> CollectionReference {
        postsCollection(communityId).document(postId).collection("comments")
    }

    // MARK: - Posts

    func listenPosts(communityId: String, type: CommunityPostType? = nil, limit: Int = 50) -> AnyPublisher<[CommunityPost], Never> {
        let subject = CurrentValueSubject<[CommunityPost], Never>([])

        var query: Query = postsCollection(communityId)
        if let type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }
        // Pinned first then by recency. Filtering isDeleted client-side
        // (composite index would be required for the server-side filter).
        query = query
            .order(by: "isPinned", descending: true)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        let listener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("[CommunityPostRepo] posts error: \(error.localizedDescription)")
                subject.send([])
                return
            }
            let posts = (snapshot?.documents.compactMap { $0.decodeCommunityPost() } ?? [])
                .filter { !$0.isDeleted }
            subject.send(posts)
        }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Listen to one specific post — used by the post detail screen so the
    /// like/bookmark/comment counts stay live.
    func listenPost(communityId: String, postId: String) -> AnyPublisher<CommunityPost?, Never> {
        let subject = CurrentValueSubject<CommunityPost?, Never>(nil)
        let listener = postsCollection(communityId).document(postId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityPostRepo] post error: \(error.localizedDescription)")
                    subject.send(nil)
                    return
                }
                let post = snapshot?.decodeCommunityPost()
                subject.send(post)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Create a post. `mediaData` are sequential JPEG byte arrays; uploaded
    /// to `communities/{id}/posts/{uuid}` then attached to the post payload.
    @discardableResult
    func createPost(_ post: CommunityPost, mediaData: [Data] = []) async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let currentUserName = auth.currentUser?.displayName ?? "Anonymous"
        let mediaUrls = try await uploadMedia(communityId: post.communityId, mediaData: mediaData)
        let authorPhoto = await resolveUserPhotoURL(userId: currentUserId)

        var working = post
        working.authorId = currentUserId
        working.authorName = currentUserName
        working.authorPhotoUrl = authorPhoto
        working.mediaUrls = mediaUrls
        let nowMs = Date().timeIntervalSince1970 * 1000
        working.createdAt = nowMs
        working.updatedAt = nowMs

        let docRef = try await postsCollection(post.communityId).addDocument(data: working.toFirestoreData())

        // Best-effort counter bumps. CF could do this, but Android does the
        // same client-side bump; ignore failures so a stale count doesn't
        // block the post's visibility (the post listener doesn't read these).
        do {
            try await communitiesCollection.document(post.communityId).updateData([
                "postCount": FieldValue.increment(Int64(1)),
                "updatedAt": nowMs
            ])
            try await communitiesCollection
                .document(post.communityId)
                .collection("members")
                .document(currentUserId)
                .updateData([
                    "postCount": FieldValue.increment(Int64(1)),
                    "lastActiveAt": nowMs
                ])
        } catch {
            print("[CommunityPostRepo] counter bump failed: \(error.localizedDescription)")
        }

        return docRef.documentID
    }

    func updatePost(communityId: String, postId: String, updates: [String: Any]) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let snapshot = try await postsCollection(communityId).document(postId).getDocument()
        guard let post = snapshot.decodeCommunityPost() else {
            throw makeError(404, "Post not found")
        }
        guard post.authorId == currentUserId else {
            throw makeError(403, "Not authorized to update this post")
        }
        var merged = updates
        merged["isEdited"] = true
        merged["updatedAt"] = Date().timeIntervalSince1970 * 1000
        try await postsCollection(communityId).document(postId).updateData(merged)
    }

    /// Soft-delete a post. Author can delete their own; moderator/admin can
    /// delete any. Mirrors Android's gatekeeping — server-side rules are the
    /// real enforcement, this is a UX guard.
    func deletePost(communityId: String, postId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let snapshot = try await postsCollection(communityId).document(postId).getDocument()
        guard let post = snapshot.decodeCommunityPost() else {
            throw makeError(404, "Post not found")
        }
        if post.authorId != currentUserId {
            let memberDoc = try await communitiesCollection
                .document(communityId)
                .collection("members")
                .document(currentUserId)
                .getDocument()
            let member = try? memberDoc.data(as: CommunityMember.self)
            guard let member, member.canModerate else {
                throw makeError(403, "Not authorized to delete this post")
            }
        }
        let nowMs = Date().timeIntervalSince1970 * 1000
        try await postsCollection(communityId).document(postId).updateData([
            "isDeleted": true,
            "updatedAt": nowMs
        ])
        // Best-effort: decrement community post count.
        do {
            try await communitiesCollection.document(communityId).updateData([
                "postCount": FieldValue.increment(Int64(-1)),
                "updatedAt": nowMs
            ])
        } catch {
            print("[CommunityPostRepo] postCount decrement failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Reactions

    /// Toggle a typed reaction. Rules (matches Android's
    /// CommunityPostRepository.toggleReaction):
    ///   - one active reaction per user per post
    ///   - same reaction → remove (toggle off)
    ///   - different reaction → swap
    ///   - no reaction → add
    /// `likedBy` mirror "any reaction" for legacy reads.
    func toggleReaction(communityId: String, postId: String, reactionType: String = "LIKE") async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let newType = reactionType.uppercased()
        let postRef = postsCollection(communityId).document(postId)

        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(postRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            let post = snapshot.decodeCommunityPost()
            guard let post else {
                errorPointer?.pointee = NSError(
                    domain: "CommunityPostRepository", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Post not found"]
                )
                return nil
            }
            let existing = post.userReaction(userId: currentUserId)
            var updates: [String: Any] = [:]
            if existing == newType {
                updates["reactions.\(newType)"] = FieldValue.arrayRemove([currentUserId])
                updates["likedBy"] = FieldValue.arrayRemove([currentUserId])
                updates["likeCount"] = FieldValue.increment(Int64(-1))
            } else if let existing {
                updates["reactions.\(existing)"] = FieldValue.arrayRemove([currentUserId])
                updates["reactions.\(newType)"] = FieldValue.arrayUnion([currentUserId])
            } else {
                updates["reactions.\(newType)"] = FieldValue.arrayUnion([currentUserId])
                updates["likedBy"] = FieldValue.arrayUnion([currentUserId])
                updates["likeCount"] = FieldValue.increment(Int64(1))
            }
            transaction.updateData(updates, forDocument: postRef)
            return nil
        }
    }

    // MARK: - Bookmarks

    func toggleBookmark(communityId: String, postId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let postRef = postsCollection(communityId).document(postId)
        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(postRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            let bookmarkedBy = (snapshot.get("bookmarkedBy") as? [String]) ?? []
            if bookmarkedBy.contains(currentUserId) {
                transaction.updateData([
                    "bookmarkedBy": FieldValue.arrayRemove([currentUserId])
                ], forDocument: postRef)
            } else {
                transaction.updateData([
                    "bookmarkedBy": FieldValue.arrayUnion([currentUserId])
                ], forDocument: postRef)
            }
            return nil
        }
    }

    // MARK: - Polls

    /// Cast or change a vote. One vote per poll per user; the existing
    /// vote is removed before the new one is added. Re-encodes the whole
    /// `pollOptions` array on write — Firestore can't atomically mutate a
    /// struct-list element by index.
    func votePoll(communityId: String, postId: String, optionId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let postRef = postsCollection(communityId).document(postId)
        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(postRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            guard let post = snapshot.decodeCommunityPost() else {
                errorPointer?.pointee = NSError(
                    domain: "CommunityPostRepository", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Post not found"]
                )
                return nil
            }
            guard post.isPoll, !post.isPollExpired else {
                errorPointer?.pointee = NSError(
                    domain: "CommunityPostRepository", code: 410,
                    userInfo: [NSLocalizedDescriptionKey: "Poll is closed"]
                )
                return nil
            }
            let updated = post.pollOptions.map { opt -> PollOption in
                let withoutUser = opt.votedBy.filter { $0 != currentUserId }
                let nextVotedBy = opt.id == optionId ? withoutUser + [currentUserId] : withoutUser
                var copy = opt
                copy.votedBy = nextVotedBy
                copy.voteCount = nextVotedBy.count
                return copy
            }
            transaction.updateData([
                "pollOptions": updated.map { $0.toFirestoreData() },
                "updatedAt": Date().timeIntervalSince1970 * 1000
            ], forDocument: postRef)
            return nil
        }
    }

    // MARK: - Pinning

    func togglePin(communityId: String, postId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let memberDoc = try await communitiesCollection
            .document(communityId)
            .collection("members")
            .document(currentUserId)
            .getDocument()
        let member = try? memberDoc.data(as: CommunityMember.self)
        guard let member, member.canModerate else {
            throw makeError(403, "Not authorized to pin posts")
        }
        let postRef = postsCollection(communityId).document(postId)
        let postSnap = try await postRef.getDocument()
        guard let post = try? postSnap.data(as: CommunityPost.self) else {
            throw makeError(404, "Post not found")
        }
        try await postRef.updateData([
            "isPinned": !post.isPinned,
            "updatedAt": Date().timeIntervalSince1970 * 1000
        ])
    }

    // MARK: - Comments

    func listenComments(communityId: String, postId: String, limit: Int = 100) -> AnyPublisher<[CommunityComment], Never> {
        let subject = CurrentValueSubject<[CommunityComment], Never>([])
        let listener = commentsCollection(communityId, postId)
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "createdAt", descending: false)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityPostRepo] comments error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let comments = snapshot?.documents.compactMap { $0.decodeCommunityComment() } ?? []
                subject.send(comments)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    @discardableResult
    func addComment(_ comment: CommunityComment) async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let currentUserName = auth.currentUser?.displayName ?? "Anonymous"
        let authorPhoto = await resolveUserPhotoURL(userId: currentUserId)

        var working = comment
        working.authorId = currentUserId
        working.authorName = currentUserName
        working.authorPhotoUrl = authorPhoto
        let nowMs = Date().timeIntervalSince1970 * 1000
        working.createdAt = nowMs
        working.updatedAt = nowMs

        let docRef = try await commentsCollection(comment.communityId, comment.postId)
            .addDocument(data: working.toFirestoreData())

        // Best-effort: bump comment counters
        do {
            try await postsCollection(comment.communityId).document(comment.postId).updateData([
                "commentCount": FieldValue.increment(Int64(1))
            ])
            try await communitiesCollection
                .document(comment.communityId)
                .collection("members")
                .document(currentUserId)
                .updateData([
                    "commentCount": FieldValue.increment(Int64(1)),
                    "lastActiveAt": nowMs
                ])
            if let parentId = comment.parentCommentId {
                try await commentsCollection(comment.communityId, comment.postId)
                    .document(parentId)
                    .updateData(["replyCount": FieldValue.increment(Int64(1))])
            }
        } catch {
            print("[CommunityPostRepo] comment counter failed: \(error.localizedDescription)")
        }

        return docRef.documentID
    }

    func toggleCommentLike(communityId: String, postId: String, commentId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let commentRef = commentsCollection(communityId, postId).document(commentId)
        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(commentRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            let likedBy = (snapshot.get("likedBy") as? [String]) ?? []
            if likedBy.contains(currentUserId) {
                transaction.updateData([
                    "likedBy": FieldValue.arrayRemove([currentUserId]),
                    "likeCount": FieldValue.increment(Int64(-1)),
                    "updatedAt": Date().timeIntervalSince1970 * 1000
                ], forDocument: commentRef)
            } else {
                transaction.updateData([
                    "likedBy": FieldValue.arrayUnion([currentUserId]),
                    "likeCount": FieldValue.increment(Int64(1)),
                    "updatedAt": Date().timeIntervalSince1970 * 1000
                ], forDocument: commentRef)
            }
            return nil
        }
    }

    func deleteComment(communityId: String, postId: String, commentId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let snapshot = try await commentsCollection(communityId, postId).document(commentId).getDocument()
        guard let comment = snapshot.decodeCommunityComment() else {
            throw makeError(404, "Comment not found")
        }
        if comment.authorId != currentUserId {
            let memberDoc = try await communitiesCollection
                .document(communityId)
                .collection("members")
                .document(currentUserId)
                .getDocument()
            let member = try? memberDoc.data(as: CommunityMember.self)
            guard let member, member.canModerate else {
                throw makeError(403, "Not authorized to delete this comment")
            }
        }
        try await commentsCollection(communityId, postId).document(commentId).updateData([
            "isDeleted": true,
            "updatedAt": Date().timeIntervalSince1970 * 1000
        ])
        do {
            try await postsCollection(communityId).document(postId).updateData([
                "commentCount": FieldValue.increment(Int64(-1))
            ])
        } catch {
            print("[CommunityPostRepo] commentCount decrement failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Reporting

    @discardableResult
    func reportContent(
        communityId: String,
        targetType: CommunityReportTargetType,
        targetId: String,
        targetAuthorId: String,
        reason: CommunityReportReason,
        description: String = ""
    ) async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let reporterName = auth.currentUser?.displayName ?? "Anonymous"

        let payload: [String: Any] = [
            "communityId": communityId,
            "reporterUserId": currentUserId,
            "reporterUserName": reporterName,
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "targetAuthorId": targetAuthorId,
            "reason": reason.rawValue,
            "description": description,
            "status": CommunityReportStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        let docRef = try await db.collection("community_reports").addDocument(data: payload)
        return docRef.documentID
    }

    // MARK: - Helpers

    private func uploadMedia(communityId: String, mediaData: [Data]) async throws -> [String] {
        guard !mediaData.isEmpty else { return [] }
        var urls: [String] = []
        for data in mediaData {
            let fileName = "communities/\(communityId)/posts/\(UUID().uuidString)"
            let ref = storage.reference().child(fileName)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL().absoluteString
            urls.append(url)
        }
        return urls
    }

    private func resolveUserPhotoURL(userId: String) async -> String? {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            if let url = snapshot.get("photoURL") as? String, !url.isEmpty {
                return url
            }
        } catch {
            print("[CommunityPostRepo] resolveUserPhotoURL: \(error.localizedDescription)")
        }
        return auth.currentUser?.photoURL?.absoluteString
    }

    private func makeError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "CommunityPostRepository", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
