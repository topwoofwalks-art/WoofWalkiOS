import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

/// Mirrors `data.repository.CommunityRepository` on Android. Owns CRUD for
/// community documents + members, chat, events, and the join/leave
/// transitions. Posts live in `CommunityPostRepository`.
///
/// Backend collections (shared with Android):
///   - `communities/{communityId}`
///   - `communities/{communityId}/members/{userId}`
///   - `communities/{communityId}/posts/{postId}`
///   - `communities/{communityId}/events/{eventId}`
///   - `communities/{communityId}/chat/{messageId}`
///   - `communities/{communityId}/joinRequests/{requestId}`
///   - `communities/{communityId}/invites/{inviteId}`
final class CommunityRepository {
    static let shared = CommunityRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()

    private init() {}

    private var communitiesCollection: CollectionReference {
        db.collection("communities")
    }

    // MARK: - CRUD

    /// Create a community + creator-as-OWNER member doc. Returns the new
    /// community id. Mirrors Android `createCommunity`.
    func createCommunity(_ community: Community) async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let currentUserName = auth.currentUser?.displayName ?? "Anonymous"

        let nowMs = Date().timeIntervalSince1970 * 1000
        var working = community
        working.createdBy = currentUserId
        working.creatorName = currentUserName
        working.memberCount = 1
        working.createdAt = nowMs
        working.updatedAt = nowMs
        if let location = working.location {
            working.geohash = encodeGeohash(latitude: location.latitude, longitude: location.longitude, precision: 9)
        }

        let docRef = try await communitiesCollection.addDocument(data: working.toFirestoreData())

        // Resolve creator photo from Firestore (auth cache may be stale).
        let creatorPhoto = await resolveUserPhotoURL(userId: currentUserId)

        var member = CommunityMember(
            userId: currentUserId,
            communityId: docRef.documentID,
            displayName: currentUserName,
            photoUrl: creatorPhoto,
            role: .owner
        )
        member.joinedAt = nowMs
        member.lastActiveAt = nowMs
        try await communitiesCollection
            .document(docRef.documentID)
            .collection("members")
            .document(currentUserId)
            .setData(member.toFirestoreData())

        print("[CommunityRepo] Community created: \(docRef.documentID)")
        return docRef.documentID
    }

    /// Update top-level community fields. Caller must be the creator OR an
    /// admin (server-side rules enforce; client checks too for clean UX).
    func updateCommunity(communityId: String, updates: [String: Any]) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }

        let snapshot = try await communitiesCollection.document(communityId).getDocument()
        guard let community = snapshot.decodeCommunity() else {
            throw makeError(404, "Community not found")
        }

        if community.createdBy != currentUserId {
            let memberDoc = try await communitiesCollection
                .document(communityId)
                .collection("members")
                .document(currentUserId)
                .getDocument()
            let member = try? memberDoc.data(as: CommunityMember.self)
            guard let member, member.canAdmin else {
                throw makeError(403, "Not authorized to update this community")
            }
        }

        var merged = updates
        merged["updatedAt"] = Date().timeIntervalSince1970 * 1000
        try await communitiesCollection.document(communityId).updateData(merged)
        print("[CommunityRepo] Community updated: \(communityId)")
    }

    func deleteCommunity(communityId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let snapshot = try await communitiesCollection.document(communityId).getDocument()
        guard let community = snapshot.decodeCommunity() else {
            throw makeError(404, "Community not found")
        }
        guard community.createdBy == currentUserId else {
            throw makeError(403, "Not authorized to delete this community")
        }
        // Top-level delete; the `cleanupCommunityOnDelete` CF
        // (functions/src/community/cleanup.ts) cascades posts/comments/
        // members/events/chat/invites/joinRequests fanout-style.
        try await communitiesCollection.document(communityId).delete()
        print("[CommunityRepo] Community deleted: \(communityId)")
    }

    /// Soft-delete a community: hides from search/discovery but keeps content.
    func archiveCommunity(communityId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let snapshot = try await communitiesCollection.document(communityId).getDocument()
        guard let community = snapshot.decodeCommunity() else {
            throw makeError(404, "Community not found")
        }
        if community.createdBy != currentUserId {
            let memberDoc = try await communitiesCollection
                .document(communityId)
                .collection("members")
                .document(currentUserId)
                .getDocument()
            let member = try? memberDoc.data(as: CommunityMember.self)
            guard let member, member.canAdmin else {
                throw makeError(403, "Not authorized to archive this community")
            }
        }
        try await communitiesCollection.document(communityId).updateData([
            "isArchived": true,
            "updatedAt": Date().timeIntervalSince1970 * 1000
        ])
        print("[CommunityRepo] Community archived: \(communityId)")
    }

    /// Upload a cover photo to Firebase Storage and (if `communityId` non-nil)
    /// patch the community doc with the new URL. When nil, uploads to a
    /// per-user draft path so the wizard can attach the URL to the create
    /// payload before the community doc exists.
    func uploadCoverPhoto(communityId: String?, imageData: Data) async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let targetId = communityId ?? "drafts/\(currentUserId)"
        let fileName = "communities/\(targetId)/cover/\(UUID().uuidString)"
        let ref = storage.reference().child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL().absoluteString

        if let communityId {
            try await communitiesCollection.document(communityId).updateData([
                "coverPhotoUrl": url,
                "updatedAt": Date().timeIntervalSince1970 * 1000
            ])
        }
        print("[CommunityRepo] Cover uploaded for \(communityId ?? "draft"): \(url)")
        return url
    }

    // MARK: - Live community doc listener

    /// Live listener for one community doc. Sends nil on permission-denied
    /// or doc-missing — never throws into the publisher chain.
    func listenCommunity(id: String) -> AnyPublisher<Community?, Never> {
        let subject = CurrentValueSubject<Community?, Never>(nil)
        let listener = communitiesCollection.document(id)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityRepo] listenCommunity error: \(error.localizedDescription)")
                    subject.send(nil)
                    return
                }
                let community = snapshot?.decodeCommunity()
                subject.send(community)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    // MARK: - Discovery listeners

    /// Discover public, non-archived communities. Filters client-side by
    /// search query (Firestore can't full-text search). Type filter is
    /// optional — when non-nil it adds a `whereField("type", ...)` server-side.
    /// Mirrors Android's discoverCommunities; the privacy lock to PUBLIC is
    /// also necessary on iOS so list-rules can prove every result satisfies
    /// the public-or-member check without get()/exists() lookups.
    func listenDiscoverCommunities(
        type: CommunityType? = nil,
        searchQuery: String? = nil,
        limit: Int = 20
    ) -> AnyPublisher<[Community], Never> {
        let subject = CurrentValueSubject<[Community], Never>([])

        var query: Query = communitiesCollection
            .whereField("isArchived", isEqualTo: false)
            .whereField("privacy", isEqualTo: CommunityPrivacy.public.rawValue)

        if let type {
            query = query.whereField("type", isEqualTo: type.rawValue)
        }
        query = query.order(by: "memberCount", descending: true).limit(to: limit)

        let listener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("[CommunityRepo] discoverCommunities error: \(error.localizedDescription)")
                subject.send([])
                return
            }
            let communities = snapshot?.documents.compactMap { doc -> Community? in
                doc.decodeCommunity()
            } ?? []

            if let q = searchQuery?.trimmingCharacters(in: .whitespaces).lowercased(),
               !q.isEmpty {
                let filtered = communities.filter { c in
                    c.name.lowercased().contains(q) ||
                    c.description.lowercased().contains(q) ||
                    c.tags.contains(where: { $0.lowercased().contains(q) })
                }
                subject.send(filtered)
            } else {
                subject.send(communities)
            }
        }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Featured (staff-picked) communities — used to populate the cold-start
    /// Discover surface so new users don't see an empty grid.
    func listenFeaturedCommunities(limit: Int = 20) -> AnyPublisher<[Community], Never> {
        let subject = CurrentValueSubject<[Community], Never>([])
        let listener = communitiesCollection
            .whereField("isFeatured", isEqualTo: true)
            .whereField("isArchived", isEqualTo: false)
            .whereField("privacy", isEqualTo: "PUBLIC")
            .order(by: "memberCount", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityRepo] featuredCommunities error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let communities = snapshot?.documents.compactMap { $0.decodeCommunity() } ?? []
                subject.send(communities)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Trending communities — top public, non-archived by memberCount.
    func listenTrendingCommunities(limit: Int = 20) -> AnyPublisher<[Community], Never> {
        let subject = CurrentValueSubject<[Community], Never>([])
        let listener = communitiesCollection
            .whereField("isArchived", isEqualTo: false)
            .whereField("privacy", isEqualTo: "PUBLIC")
            .order(by: "memberCount", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityRepo] trendingCommunities error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let communities = snapshot?.documents.compactMap { $0.decodeCommunity() } ?? []
                subject.send(communities)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Communities the current user is a member of. Pulls via collectionGroup
    /// on `members` then re-fetches the parent docs in batches of 10
    /// (Firestore's whereIn limit) — same approach as Android.
    func listenMyCommunities(userId: String) -> AnyPublisher<[Community], Never> {
        let subject = CurrentValueSubject<[Community], Never>([])
        let listener = db.collectionGroup("members")
            .whereField("userId", isEqualTo: userId)
            .whereField("isBanned", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("[CommunityRepo] myCommunities error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let communityIds: [String] = snapshot?.documents.compactMap { doc in
                    // Path: communities/{communityId}/members/{userId}
                    doc.reference.parent.parent?.documentID
                } ?? []

                if communityIds.isEmpty {
                    subject.send([])
                    return
                }

                Task {
                    var collected: [Community] = []
                    for batch in communityIds.chunked(into: 10) {
                        let refs = batch.map { self.communitiesCollection.document($0) }
                        do {
                            let chunkSnapshot = try await self.communitiesCollection
                                .whereField(FieldPath.documentID(), in: refs)
                                .getDocuments()
                            let chunk = chunkSnapshot.documents.compactMap {
                                $0.decodeCommunity()
                            }.filter { !$0.isArchived }
                            collected.append(contentsOf: chunk)
                        } catch {
                            print("[CommunityRepo] myCommunities batch error: \(error.localizedDescription)")
                        }
                    }
                    subject.send(collected)
                }
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    // MARK: - Join / Leave

    /// Public communities: write the member doc directly. Private: throws —
    /// caller must use `CommunityMemberRepository.createJoinRequest`.
    /// Invite-only: throws.
    func joinCommunity(communityId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let currentUserName = auth.currentUser?.displayName ?? "Anonymous"

        let snapshot = try await communitiesCollection.document(communityId).getDocument()
        guard let community = snapshot.decodeCommunity() else {
            throw makeError(404, "Community not found")
        }
        if community.requiresInvite {
            throw makeError(403, "This community requires an invitation to join")
        }
        if community.isPrivate {
            throw makeError(403, "This community requires approval. Use createJoinRequest.")
        }

        let memberRef = communitiesCollection
            .document(communityId)
            .collection("members")
            .document(currentUserId)

        let existing = try await memberRef.getDocument()
        if existing.exists {
            throw makeError(409, "Already a member of this community")
        }

        let joinPhoto = await resolveUserPhotoURL(userId: currentUserId)
        var member = CommunityMember(
            userId: currentUserId,
            communityId: communityId,
            displayName: currentUserName,
            photoUrl: joinPhoto,
            role: .member
        )
        let nowMs = Date().timeIntervalSince1970 * 1000
        member.joinedAt = nowMs
        member.lastActiveAt = nowMs

        // Only the member doc — `onCommunityMemberWrite` CF maintains parent
        // memberCount / updatedAt server-side. Self-joiners aren't admins,
        // so a client-side parent-doc update fails the rules' admin check.
        try await memberRef.setData(member.toFirestoreData())
        print("[CommunityRepo] Joined community: \(communityId)")
    }

    func leaveCommunity(communityId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let memberRef = communitiesCollection
            .document(communityId)
            .collection("members")
            .document(currentUserId)
        let memberDoc = try await memberRef.getDocument()
        guard let member = try? memberDoc.data(as: CommunityMember.self) else {
            throw makeError(404, "Not a member of this community")
        }
        if member.isOwner {
            throw makeError(403, "Owner cannot leave. Transfer ownership first.")
        }
        try await memberRef.delete()
        print("[CommunityRepo] Left community: \(communityId)")
    }

    // MARK: - Members

    func getMemberRole(communityId: String, userId: String) async throws -> CommunityMemberRole? {
        let doc = try await communitiesCollection
            .document(communityId)
            .collection("members")
            .document(userId)
            .getDocument()
        guard doc.exists else { return nil }
        let member = doc.decodeCommunityMember()
        return member?.role
    }

    /// Listen to the non-banned members of a community, sorted by role then
    /// joinedAt. Used by both Members tab and the moderation screen.
    func listenCommunityMembers(communityId: String) -> AnyPublisher<[CommunityMember], Never> {
        let subject = CurrentValueSubject<[CommunityMember], Never>([])
        let listener = communitiesCollection
            .document(communityId)
            .collection("members")
            .whereField("isBanned", isEqualTo: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityRepo] members error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let members = snapshot?.documents.compactMap { doc -> CommunityMember? in
                    var m = doc.decodeCommunityMember()
                    if m?.userId.isEmpty ?? true { m?.userId = doc.documentID }
                    return m
                } ?? []
                let sorted = members.sorted {
                    if $0.role.sortOrder == $1.role.sortOrder {
                        return $0.joinedAt > $1.joinedAt
                    }
                    return $0.role.sortOrder < $1.role.sortOrder
                }
                subject.send(sorted)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    // MARK: - Posts (live listener — full posts repo lives in CommunityPostRepository)

    /// Live posts listener used by the Feed tab. Posts written client-side
    /// hit the snapshot in <1s. Pinned posts are NOT pre-sorted here — the
    /// detail-screen ViewModel splits pinned vs. regular based on `isPinned`.
    func listenCommunityPosts(communityId: String, limit: Int = 50) -> AnyPublisher<[CommunityPost], Never> {
        let subject = CurrentValueSubject<[CommunityPost], Never>([])
        let listener = communitiesCollection
            .document(communityId)
            .collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityRepo] posts error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                // Filter isDeleted client-side — combining whereField with
                // the createdAt order needs a composite index that wasn't
                // shipped (see Android comment in CommunityRepository.kt:529).
                let posts = (snapshot?.documents.compactMap { $0.decodeCommunityPost() } ?? [])
                    .filter { !$0.isDeleted }
                subject.send(posts)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    // MARK: - Events

    func listenCommunityEvents(communityId: String) -> AnyPublisher<[CommunityEvent], Never> {
        let subject = CurrentValueSubject<[CommunityEvent], Never>([])
        let listener = communitiesCollection
            .document(communityId)
            .collection("events")
            .whereField("status", in: ["UPCOMING", "ONGOING"])
            .order(by: "startTime", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityRepo] events error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let events = snapshot?.documents.compactMap { $0.decodeCommunityEvent() } ?? []
                subject.send(events)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Toggle attendance for the current user. Atomic transaction so multiple
    /// taps don't double-count. Reads the doc, mutates `attendeeIds`, writes
    /// back along with derived `attendeeCount`.
    func toggleEventAttendance(communityId: String, eventId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let eventRef = communitiesCollection
            .document(communityId)
            .collection("events")
            .document(eventId)

        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(eventRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            var attendeeIds = (snapshot.get("attendeeIds") as? [String]) ?? []
            if attendeeIds.contains(currentUserId) {
                attendeeIds.removeAll { $0 == currentUserId }
            } else {
                attendeeIds.append(currentUserId)
            }
            transaction.updateData([
                "attendeeIds": attendeeIds,
                "attendeeCount": attendeeIds.count,
                "updatedAt": Date().timeIntervalSince1970 * 1000
            ], forDocument: eventRef)
            return nil
        }
    }

    // MARK: - Chat

    func listenCommunityChat(communityId: String, limit: Int = 100) -> AnyPublisher<[CommunityChatMessage], Never> {
        let subject = CurrentValueSubject<[CommunityChatMessage], Never>([])
        let listener = communitiesCollection
            .document(communityId)
            .collection("chat")
            .order(by: "createdAt", descending: false)
            .limit(toLast: limit)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[CommunityRepo] chat error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let messages = snapshot?.documents.compactMap { $0.decodeCommunityChatMessage() } ?? []
                subject.send(messages)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Send a chat message. Returns the new message id on success — caller
    /// shows snackbar+retry on throw, not silent drop (see Android
    /// CommunityChatTab.kt for the same retry UX).
    @discardableResult
    func sendChatMessage(communityId: String, text: String) async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw makeError(400, "Message is empty")
        }
        let currentUserName = auth.currentUser?.displayName ?? "Anonymous"
        let photoUrl = await resolveUserPhotoURL(userId: currentUserId)

        let payload: [String: Any] = [
            "authorId": currentUserId,
            "authorName": currentUserName,
            "authorPhotoUrl": photoUrl ?? NSNull(),
            "content": trimmed,
            "createdAt": Date().timeIntervalSince1970 * 1000
        ]
        let docRef = try await communitiesCollection
            .document(communityId)
            .collection("chat")
            .addDocument(data: payload)
        return docRef.documentID
    }

    func deleteChatMessage(communityId: String, messageId: String) async throws {
        guard auth.currentUser?.uid != nil else {
            throw makeError(401, "Not authenticated")
        }
        try await communitiesCollection
            .document(communityId)
            .collection("chat")
            .document(messageId)
            .delete()
    }

    // MARK: - Helpers

    /// Read user photoURL from Firestore (canonical source) with auth.photoURL
    /// fallback. Mirrors `firestore.collection("users").document(uid).get()`
    /// pattern used pervasively on Android — auth.currentUser.photoURL is
    /// often a stale cached Google avatar.
    private func resolveUserPhotoURL(userId: String) async -> String? {
        do {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            if let url = snapshot.get("photoURL") as? String, !url.isEmpty {
                return url
            }
        } catch {
            print("[CommunityRepo] resolveUserPhotoURL: \(error.localizedDescription)")
        }
        return auth.currentUser?.photoURL?.absoluteString
    }

    /// Encode lat/lng to a base-32 geohash. Compact local impl — avoids
    /// pulling another dep just for the location community feature. Output
    /// matches Android's `GeoHashUtil.encode` to the same precision.
    private func encodeGeohash(latitude: Double, longitude: Double, precision: Int) -> String {
        let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
        var lat = (-90.0, 90.0)
        var lon = (-180.0, 180.0)
        var hash = ""
        var bits = 0
        var ch = 0
        var even = true
        while hash.count < precision {
            if even {
                let mid = (lon.0 + lon.1) / 2
                if longitude > mid {
                    ch = (ch << 1) | 1
                    lon.0 = mid
                } else {
                    ch = ch << 1
                    lon.1 = mid
                }
            } else {
                let mid = (lat.0 + lat.1) / 2
                if latitude > mid {
                    ch = (ch << 1) | 1
                    lat.0 = mid
                } else {
                    ch = ch << 1
                    lat.1 = mid
                }
            }
            even.toggle()
            bits += 1
            if bits == 5 {
                hash.append(base32[ch])
                bits = 0
                ch = 0
            }
        }
        return hash
    }

    private func makeError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "CommunityRepository", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// Array.chunked(into:) lives in Extensions/Array+Chunked.swift — single
// canonical definition shared with UserRepository. Was duplicated here
// fileprivate which Release-mode Swift still rejected as a clash.
