import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class UserRepository: ObservableObject {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    func hasUserProfile() async throws -> Bool {
        guard let userId = auth.currentUser?.uid else { return false }
        let doc = try await db.collection("users").document(userId).getDocument()
        return doc.exists
    }

    func createUserProfile(username: String, email: String) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let profile = UserProfile(
            id: userId,
            username: username,
            email: email,
            photoUrl: auth.currentUser?.photoURL?.absoluteString,
            pawPoints: 0,
            level: 1,
            badges: [],
            dogs: [],
            createdAt: Timestamp(date: Date()),
            regionCode: ""
        )

        try db.collection("users").document(userId).setData(from: profile)
        return userId
    }

    func updateUserProfile(updates: [String: Any]) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("users").document(userId).updateData(updates)
    }

    func getUserProfile(userId: String? = nil) -> AnyPublisher<UserProfile?, Error> {
        guard let uid = userId ?? auth.currentUser?.uid else {
            return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        let publisher = PassthroughSubject<UserProfile?, Error>()

        db.collection("users").document(uid).addSnapshotListener { snapshot, error in
            if let error = error {
                publisher.send(completion: .failure(error))
                return
            }

            guard let snapshot = snapshot else {
                publisher.send(nil)
                return
            }

            do {
                let user = try snapshot.data(as: UserProfile.self)
                publisher.send(user)
            } catch {
                publisher.send(completion: .failure(error))
            }
        }

        return publisher.eraseToAnyPublisher()
    }

    // Dog CRUD is now exclusively through DogRepository — callers have
    // been migrated to call it directly. The legacy addDogProfile/
    // updateDogProfile/removeDogProfile shims were deleted in Stage 3.

    // MARK: - Gamification writes (server-authority stubs)
    // All counter increments, badge detection, level recompute, and
    // streak updates are owned by Cloud Functions (onWalkComplete,
    // contributionTriggers, reconcileStats). Client-side calls here
    // are no-ops so existing call sites compile without changes.

    func awardPawPoints(points: Int, reason: String) async throws {
        print("[gamification] awardPawPoints stub: \(points)pt for \(reason) — server CF owns this")
    }

    func updateWalkStats(distanceMeters: Double) async throws {
        print("[gamification] updateWalkStats stub: \(distanceMeters)m — server CF owns this")
    }

    func awardBadge(badgeId: String) async throws {
        print("[gamification] awardBadge stub: \(badgeId) — server CF owns this")
    }

    func getLeaderboard(regionCode: String? = nil, limit: Int = 100) async throws -> [UserProfile] {
        var query: Query = db.collection("users")
            .order(by: "pawPoints", descending: true)
            .limit(to: limit)

        if let regionCode = regionCode {
            query = query.whereField("regionCode", isEqualTo: regionCode)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: UserProfile.self) }
    }

    func getFriendsLeaderboard(friendIds: [String]) async throws -> [UserProfile] {
        guard !friendIds.isEmpty else { return [] }

        let chunks = friendIds.chunked(into: 10)
        var allUsers: [UserProfile] = []

        for chunk in chunks {
            // Use FieldPath.documentID — UserProfile.id is @DocumentID
            // (not stored as a field) so the previous whereField("id", in:
            // chunk) returned nothing. Bug audit 2026-05-05.
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            let users = try snapshot.documents.compactMap { try $0.data(as: UserProfile.self) }
            allUsers.append(contentsOf: users)
        }

        return allUsers.sorted { $0.pawPoints > $1.pawPoints }
    }

    /// Self-contained Friends leaderboard. Queries /friendships directly
    /// for the current user's accepted friendships rather than depending
    /// on a side-channel @Published property that may not have been
    /// populated when the user opens Leaderboard before Social. Mirrors
    /// Android `getFriendsLeaderboardDirect`.
    func getFriendsLeaderboardDirect() async throws -> [UserProfile] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }

        async let side1Snap = db.collection("friendships")
            .whereField("userId1", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "ACCEPTED")
            .getDocuments()
        async let side2Snap = db.collection("friendships")
            .whereField("userId2", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "ACCEPTED")
            .getDocuments()

        let s1 = try await side1Snap
        let s2 = try await side2Snap

        var friendIds = Set<String>()
        for doc in s1.documents {
            if let other = doc["userId2"] as? String { friendIds.insert(other) }
        }
        for doc in s2.documents {
            if let other = doc["userId1"] as? String { friendIds.insert(other) }
        }

        // Always include the current user so they see their own ranking
        // among friends.
        friendIds.insert(currentUserId)

        return try await getFriendsLeaderboard(friendIds: Array(friendIds))
    }

    // MARK: - Friend Request Workflow (matches Android FriendRepository)

    /// Canonical friendship doc ID: `"{lowerUid}_{higherUid}"`.
    ///
    /// A single pair has exactly one doc regardless of which side sent
    /// the request, making duplicates structurally impossible. Stored
    /// fields follow the same ordering (userId1 < userId2
    /// lexicographically) so reads can query either direction without
    /// missing records. Mirrors FriendRepository.kt on Android.
    private func canonicalPair(_ a: String, _ b: String) -> (lo: String, hi: String) {
        return a <= b ? (a, b) : (b, a)
    }

    private func canonicalFriendshipId(_ a: String, _ b: String) -> String {
        let pair = canonicalPair(a, b)
        return "\(pair.lo)_\(pair.hi)"
    }

    /// Send a friend request. Race-safe via a transaction that collapses
    /// two simultaneous "friend them / friend you" taps into one doc.
    ///   1. No existing doc      -> create PENDING
    ///   2. PENDING by us        -> already-sent error
    ///   3. PENDING by other side -> upgrade to ACCEPTED (reverse accept)
    ///   4. ACCEPTED             -> already-friends error
    ///   5. BLOCKED              -> cannot-request error
    func sendFriendRequest(toUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        guard userId != toUserId else {
            throw NSError(domain: "UserRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot send friend request to yourself"])
        }

        let pair = canonicalPair(userId, toUserId)
        let docId = "\(pair.lo)_\(pair.hi)"
        let docRef = db.collection("friendships").document(docId)

        _ = try await db.runTransaction { txn, errorPointer -> Any? in
            let snap: DocumentSnapshot
            do {
                snap = try txn.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            if let data = snap.data() {
                let status = data["status"] as? String ?? ""
                let requestedBy = data["requestedBy"] as? String ?? ""
                switch status {
                case FriendStatus.blocked.rawValue:
                    errorPointer?.pointee = NSError(domain: "UserRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot send friend request to this user"])
                    return nil
                case FriendStatus.accepted.rawValue:
                    errorPointer?.pointee = NSError(domain: "UserRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Already friends with this user"])
                    return nil
                case FriendStatus.pending.rawValue:
                    if requestedBy == userId {
                        errorPointer?.pointee = NSError(domain: "UserRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Friend request already sent"])
                        return nil
                    }
                    // Other side already requested us — reverse-accept.
                    txn.updateData([
                        "status": FriendStatus.accepted.rawValue,
                        "acceptedAt": FieldValue.serverTimestamp()
                    ], forDocument: docRef)
                default:
                    errorPointer?.pointee = NSError(domain: "UserRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Cannot send friend request"])
                    return nil
                }
            } else {
                txn.setData([
                    "userId1": pair.lo,
                    "userId2": pair.hi,
                    "status": FriendStatus.pending.rawValue,
                    "requestedBy": userId,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: docRef)
            }
            return nil
        }

        // Notifications (PENDING create, PENDING→ACCEPTED update) are
        // emitted server-side by onFriendshipWrite — /notifications
        // rejects client writes (allow create: if false).
        print("Friend request sent / reverse-accepted: \(docId)")
    }

    /// Accept an incoming friend request. Updates status to ACCEPTED.
    func acceptFriendRequest(friendshipId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let doc = try await db.collection("friendships").document(friendshipId).getDocument()
        guard let data = doc.data() else {
            throw NSError(domain: "UserRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Friendship not found"])
        }

        let userId1 = data["userId1"] as? String ?? ""
        let userId2 = data["userId2"] as? String ?? ""
        let requestedBy = data["requestedBy"] as? String ?? ""

        guard userId1 == userId || userId2 == userId else {
            throw NSError(domain: "UserRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to accept this request"])
        }

        guard requestedBy != userId else {
            throw NSError(domain: "UserRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot accept your own friend request"])
        }

        try await db.collection("friendships").document(friendshipId).updateData([
            "status": FriendStatus.accepted.rawValue,
            "acceptedAt": FieldValue.serverTimestamp()
        ])

        // Acceptance notification to the original requester is created
        // server-side by onFriendshipWrite (PENDING → ACCEPTED transition).

        print("Friend request accepted: \(friendshipId)")
    }

    /// Cancel an outgoing friend request the current user sent. Mirrors
    /// the Sent-tab "Cancel" button on Android. Only allowed when the
    /// doc is still PENDING and the current user is the original
    /// requester — otherwise we'd be letting either side blow away an
    /// accepted friendship via this codepath.
    func cancelFriendRequest(friendshipId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let doc = try await db.collection("friendships").document(friendshipId).getDocument()
        guard let data = doc.data() else {
            throw NSError(domain: "UserRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Friendship not found"])
        }

        let status = data["status"] as? String ?? ""
        let requestedBy = data["requestedBy"] as? String ?? ""

        guard status == FriendStatus.pending.rawValue else {
            throw NSError(domain: "UserRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Can only cancel pending requests"])
        }
        guard requestedBy == userId else {
            throw NSError(domain: "UserRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the sender can cancel a request"])
        }

        try await db.collection("friendships").document(friendshipId).delete()
        print("Outgoing friend request cancelled: \(friendshipId)")
    }

    /// Reject/decline an incoming friend request. Deletes the friendship doc.
    func rejectFriendRequest(friendshipId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let doc = try await db.collection("friendships").document(friendshipId).getDocument()
        guard let data = doc.data() else {
            throw NSError(domain: "UserRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Friendship not found"])
        }

        let userId1 = data["userId1"] as? String ?? ""
        let userId2 = data["userId2"] as? String ?? ""

        guard userId1 == userId || userId2 == userId else {
            throw NSError(domain: "UserRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to decline this request"])
        }

        try await db.collection("friendships").document(friendshipId).delete()
        print("Friend request declined: \(friendshipId)")
    }

    /// Remove an existing friend (delete the friendship doc).
    func removeFriend(friendshipId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let doc = try await db.collection("friendships").document(friendshipId).getDocument()
        guard let data = doc.data() else {
            throw NSError(domain: "UserRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Friendship not found"])
        }

        let userId1 = data["userId1"] as? String ?? ""
        let userId2 = data["userId2"] as? String ?? ""

        guard userId1 == userId || userId2 == userId else {
            throw NSError(domain: "UserRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to remove this friendship"])
        }

        try await db.collection("friendships").document(friendshipId).delete()
        print("Friend removed: \(friendshipId)")
    }

    /// Remove friend by their user ID (convenience, looks up the friendship doc first).
    func removeFriendByUserId(friendUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        guard let friendship = try await getFriendshipBetween(userId1: userId, userId2: friendUserId),
              let docId = friendship["docId"] as? String else {
            throw NSError(domain: "UserRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Friendship not found"])
        }

        try await db.collection("friendships").document(docId).delete()
        print("Friend removed by userId: \(friendUserId)")
    }

    /// Get the friendship status between the current user and another user.
    func getFriendshipStatus(userId targetUserId: String) async throws -> (status: FriendStatus?, friendshipId: String?, requestedBy: String?) {
        guard let userId = auth.currentUser?.uid else {
            return (nil, nil, nil)
        }

        guard let friendship = try await getFriendshipBetween(userId1: userId, userId2: targetUserId) else {
            return (nil, nil, nil)
        }

        let statusStr = friendship["status"] as? String ?? ""
        let docId = friendship["docId"] as? String
        let requestedBy = friendship["requestedBy"] as? String
        return (FriendStatus(rawValue: statusStr), docId, requestedBy)
    }

    /// Real-time listener for accepted friends (uses "friendships" collection).
    func getFriends() -> AnyPublisher<[UserProfile], Error> {
        guard let userId = auth.currentUser?.uid else {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        let publisher = PassthroughSubject<[UserProfile], Error>()
        var friendIds1 = Set<String>()
        var friendIds2 = Set<String>()

        // We need two listeners since Firestore can't do OR queries.
        // Listener 1: where userId1 == currentUser and status == ACCEPTED
        db.collection("friendships")
            .whereField("userId1", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendStatus.accepted.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Friends listener (userId1) error: \(error.localizedDescription)")
                    return
                }

                friendIds1.removeAll()
                for doc in snapshot?.documents ?? [] {
                    let data = doc.data()
                    if let id2 = data["userId2"] as? String {
                        friendIds1.insert(id2)
                    }
                }

                let allFriendIds = friendIds1.union(friendIds2)
                self?.fetchUserProfiles(ids: Array(allFriendIds), publisher: publisher)
            }

        // Listener 2: where userId2 == currentUser and status == ACCEPTED
        db.collection("friendships")
            .whereField("userId2", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendStatus.accepted.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Friends listener (userId2) error: \(error.localizedDescription)")
                    return
                }

                friendIds2.removeAll()
                for doc in snapshot?.documents ?? [] {
                    let data = doc.data()
                    if let id1 = data["userId1"] as? String {
                        friendIds2.insert(id1)
                    }
                }

                let allFriendIds = friendIds1.union(friendIds2)
                self?.fetchUserProfiles(ids: Array(allFriendIds), publisher: publisher)
            }

        return publisher.eraseToAnyPublisher()
    }

    // MARK: - Private helpers for friend system

    private func fetchUserProfiles(ids: [String], publisher: PassthroughSubject<[UserProfile], Error>) {
        if ids.isEmpty {
            publisher.send([])
            return
        }

        Task {
            do {
                var users: [UserProfile] = []
                for chunk in ids.chunked(into: 10) {
                    let snapshot = try await db.collection("users")
                        .whereField("id", in: chunk)
                        .getDocuments()
                    let chunkUsers = try snapshot.documents.compactMap { try $0.data(as: UserProfile.self) }
                    users.append(contentsOf: chunkUsers)
                }
                publisher.send(users)
            } catch {
                publisher.send(completion: .failure(error))
            }
        }
    }

    /// Look up the friendship between two users via the canonical doc ID.
    /// A single `getDocument` replaces the previous two directional queries.
    private func getFriendshipBetween(userId1: String, userId2: String) async throws -> [String: Any]? {
        let docId = canonicalFriendshipId(userId1, userId2)
        let snap = try await db.collection("friendships").document(docId).getDocument()
        guard var data = snap.data() else { return nil }
        data["docId"] = snap.documentID
        return data
    }

    // MARK: - Block / Mute (feed visibility controls)
    //
    // Block: stored symmetrically in /friendships with status=BLOCKED
    // and requestedBy=blocker. Mirrors Android FriendRepository.blockUser
    // exactly so the same Cloud Functions / triggers / portal queries
    // see one schema across platforms.
    //
    // Mute: stored as an array union on /feed_preferences/{uid}.mutedUsers.
    // Mirrors Android FeedRepository.muteUser / unmuteUser. The feed
    // viewmodel reads this on session start (and after each block /
    // mute action) into an in-memory Set for O(1) post filtering.

    /// Block another user. Their posts disappear from the current
    /// user's feed and friend requests/messages from them are blocked.
    /// The action is symmetric (both sides hidden from each other)
    /// because the underlying /friendships doc covers both directions.
    func blockUser(_ targetUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        guard userId != targetUserId else {
            throw NSError(domain: "UserRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot block yourself"])
        }

        let pair = canonicalPair(userId, targetUserId)
        let docId = "\(pair.lo)_\(pair.hi)"

        // setData overwrites any existing PENDING / ACCEPTED state —
        // blocking implicitly drops the friendship. requestedBy stays
        // the blocker so unblockUser can gate on it.
        try await db.collection("friendships").document(docId).setData([
            "userId1": pair.lo,
            "userId2": pair.hi,
            "status": FriendStatus.blocked.rawValue,
            "requestedBy": userId,
            "createdAt": FieldValue.serverTimestamp()
        ])
        print("[UserRepository] User blocked: \(docId)")
    }

    /// Unblock a previously blocked user. Only the original blocker
    /// (tracked via `requestedBy` on the friendship doc) can unblock —
    /// mirrors Android FriendRepository.unblockUser.
    func unblockUser(_ targetUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let pair = canonicalPair(userId, targetUserId)
        let docId = "\(pair.lo)_\(pair.hi)"
        let docRef = db.collection("friendships").document(docId)
        let snap = try await docRef.getDocument()

        guard let data = snap.data() else {
            throw NSError(domain: "UserRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Block not found"])
        }
        let status = data["status"] as? String ?? ""
        let requestedBy = data["requestedBy"] as? String ?? ""

        guard status == FriendStatus.blocked.rawValue else {
            throw NSError(domain: "UserRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "User is not blocked"])
        }
        // Canonicalised docs sort (userId1, userId2) lexicographically,
        // so userId1 doesn't identify the blocker. Gate on requestedBy
        // — otherwise the blocked party could lift the block whenever
        // their uid happened to sort to userId1.
        guard requestedBy == userId else {
            throw NSError(domain: "UserRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to unblock this user"])
        }

        try await docRef.delete()
        print("[UserRepository] User unblocked: \(docId)")
    }

    /// Mute a user — their posts disappear from the feed without the
    /// stronger consequences of blocking (DMs / friend requests still
    /// work; they don't know they've been muted). Stored as an
    /// array-union on /feed_preferences/{uid}.mutedUsers, mirroring
    /// Android FeedRepository.muteUser.
    func muteUser(_ targetUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        guard userId != targetUserId else {
            throw NSError(domain: "UserRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot mute yourself"])
        }

        // setData(merge:true) instead of updateData — first-ever mute
        // creates the prefs doc, subsequent mutes union into it. Matches
        // Android's `update` which assumes the doc exists; using merge
        // here covers the first-mute bootstrap without an extra read.
        try await db.collection("feed_preferences").document(userId).setData([
            "mutedUsers": FieldValue.arrayUnion([targetUserId]),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        print("[UserRepository] User muted: \(targetUserId)")
    }

    /// Unmute a user. arrayRemove on the same prefs doc.
    func unmuteUser(_ targetUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("feed_preferences").document(userId).updateData([
            "mutedUsers": FieldValue.arrayRemove([targetUserId]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        print("[UserRepository] User unmuted: \(targetUserId)")
    }

}

// Array.chunked(into:) is now in Extensions/Array+Chunked.swift — single
// canonical definition shared with CommunityRepository.

/// Wire-format badge IDs — must match `BADGES[].id` in
/// `functions/src/gamification/badges.ts`.
enum BadgeIds {
    static let firstWalk      = "first_walk"
    static let walk5km        = "walk_5km"
    static let walk10km       = "walk_10km"
    static let walkMarathon   = "walk_marathon"
    static let walk100Total   = "walk_100_total"
    static let earlyBird      = "early_bird"
    static let nightOwl       = "night_owl"
    static let explorer       = "explorer"
    static let firstPoi       = "first_poi"
    static let contributor    = "contributor"
    static let poiCreator50   = "poi_creator_50"
    static let photoMaster    = "photo_master"
    static let guardian       = "guardian"
    static let social         = "social"
}

enum PointRewards {
    static let completeWalk = 10
    static let addPoi = 5
    static let addPhoto = 3
    static let addComment = 2
    static let votePoi = 1
    static let verifyPoi = 5
    static let dailyWalk = 5
}
