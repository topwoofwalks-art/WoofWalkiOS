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

    func addDogProfile(dog: DogProfile) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let userDoc = try await db.collection("users").document(userId).getDocument()
        let user = try userDoc.data(as: UserProfile.self)

        if user.dogs.contains(where: { $0.id == dog.id }) {
            print("Dog profile already exists: \(dog.name), skipping")
            return
        }

        try await db.collection("users").document(userId).updateData([
            "dogs": FieldValue.arrayUnion([try Firestore.Encoder().encode(dog)])
        ])
    }

    func updateDogProfile(dogId: String, dog: DogProfile) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let userDoc = try await db.collection("users").document(userId).getDocument()
        var user = try userDoc.data(as: UserProfile.self)

        if let index = user.dogs.firstIndex(where: { $0.id == dogId }) {
            user.dogs[index] = dog
            try await db.collection("users").document(userId).updateData([
                "dogs": user.dogs.map { try! Firestore.Encoder().encode($0) }
            ])
        }
    }

    func removeDogProfile(dogId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let userDoc = try await db.collection("users").document(userId).getDocument()
        let user = try userDoc.data(as: UserProfile.self)

        guard let dog = user.dogs.first(where: { $0.id == dogId }) else {
            throw NSError(domain: "UserRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Dog not found"])
        }

        try await db.collection("users").document(userId).updateData([
            "dogs": FieldValue.arrayRemove([try Firestore.Encoder().encode(dog)])
        ])
    }

    func awardPawPoints(points: Int, reason: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("users").document(userId).updateData([
            "pawPoints": FieldValue.increment(Int64(points))
        ])

        try await checkAndUpdateLevel(userId: userId)
        print("Awarded \(points) paw points for: \(reason)")
    }

    func updateWalkStats(distanceMeters: Double) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await db.collection("users").document(userId).updateData([
            "totalWalks": FieldValue.increment(Int64(1)),
            "totalDistanceMeters": FieldValue.increment(Int64(distanceMeters))
        ])
    }

    private func checkAndUpdateLevel(userId: String) async throws {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let user = try userDoc.data(as: UserProfile.self)
        let newLevel = calculateLevel(pawPoints: user.pawPoints)

        if newLevel > user.level {
            try await db.collection("users").document(userId).updateData([
                "level": newLevel
            ])
            print("User leveled up to \(newLevel)")
        }
    }

    private func calculateLevel(pawPoints: Int) -> Int {
        switch pawPoints {
        case ..<100: return 1
        case 100..<300: return 2
        case 300..<600: return 3
        case 600..<1000: return 4
        case 1000..<1500: return 5
        case 1500..<2100: return 6
        case 2100..<2800: return 7
        case 2800..<3600: return 8
        case 3600..<4500: return 9
        case 4500..<5500: return 10
        default: return 10 + (pawPoints - 5500) / 1000
        }
    }

    func awardBadge(badgeId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let userDoc = try await db.collection("users").document(userId).getDocument()
        let user = try userDoc.data(as: UserProfile.self)

        if user.badges.contains(badgeId) {
            print("Badge already awarded: \(badgeId)")
            return
        }

        try await db.collection("users").document(userId).updateData([
            "badges": FieldValue.arrayUnion([badgeId])
        ])
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
            let snapshot = try await db.collection("users")
                .whereField("id", in: chunk)
                .getDocuments()

            let users = try snapshot.documents.compactMap { try $0.data(as: UserProfile.self) }
            allUsers.append(contentsOf: users)
        }

        return allUsers.sorted { $0.pawPoints > $1.pawPoints }
    }

    // MARK: - Friend Request Workflow (matches Android FriendRepository)

    /// Send a friend request to another user. Creates a doc in "friendships" with status PENDING.
    func sendFriendRequest(toUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        guard userId != toUserId else {
            throw NSError(domain: "UserRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot send friend request to yourself"])
        }

        // Check for existing friendship in either direction
        let existing = try await getFriendshipBetween(userId1: userId, userId2: toUserId)
        if let existing = existing {
            let status = existing["status"] as? String ?? ""
            switch status {
            case FriendStatus.pending.rawValue:
                throw NSError(domain: "UserRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Friend request already sent"])
            case FriendStatus.accepted.rawValue:
                throw NSError(domain: "UserRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Already friends with this user"])
            case FriendStatus.blocked.rawValue:
                throw NSError(domain: "UserRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot send friend request to this user"])
            default:
                break
            }
        }

        let friendshipData: [String: Any] = [
            "userId1": userId,
            "userId2": toUserId,
            "status": FriendStatus.pending.rawValue,
            "requestedBy": userId,
            "createdAt": FieldValue.serverTimestamp()
        ]

        let docRef = try await db.collection("friendships").addDocument(data: friendshipData)

        // Create notification for the target user
        try? await createFriendNotification(
            userId: toUserId,
            type: "FRIEND_REQUEST",
            title: "New Friend Request",
            body: "You have a new friend request",
            metadata: ["friendshipId": docRef.documentID, "fromUserId": userId]
        )

        print("Friend request sent: \(docRef.documentID)")
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

        // Notify the requester
        try? await createFriendNotification(
            userId: requestedBy,
            type: "FRIEND_ACCEPTED",
            title: "Friend Request Accepted",
            body: "Your friend request was accepted",
            metadata: ["friendshipId": friendshipId, "fromUserId": userId]
        )

        print("Friend request accepted: \(friendshipId)")
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

    /// Look up an existing friendship doc between two users (in either direction).
    private func getFriendshipBetween(userId1: String, userId2: String) async throws -> [String: Any]? {
        // Check userId1 -> userId2
        let snapshot1 = try await db.collection("friendships")
            .whereField("userId1", isEqualTo: userId1)
            .whereField("userId2", isEqualTo: userId2)
            .getDocuments()

        if let doc = snapshot1.documents.first {
            var data = doc.data()
            data["docId"] = doc.documentID
            return data
        }

        // Check userId2 -> userId1 (reverse direction)
        let snapshot2 = try await db.collection("friendships")
            .whereField("userId1", isEqualTo: userId2)
            .whereField("userId2", isEqualTo: userId1)
            .getDocuments()

        if let doc = snapshot2.documents.first {
            var data = doc.data()
            data["docId"] = doc.documentID
            return data
        }

        return nil
    }

    /// Create a notification document for friend-related events.
    private func createFriendNotification(userId: String, type: String, title: String, body: String, metadata: [String: String]) async throws {
        let notification: [String: Any] = [
            "userId": userId,
            "type": type,
            "title": title,
            "body": body,
            "read": false,
            "metadata": metadata,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("notifications").addDocument(data: notification)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

enum BadgeIds {
    static let firstWalk = "first_walk"
    static let walk5km = "walk_5km"
    static let walk10km = "walk_10km"
    static let walkMarathon = "walk_marathon"
    static let walk100Total = "walk_100_total"
    static let firstPoi = "first_poi"
    static let poiCreator10 = "poi_creator_10"
    static let poiCreator50 = "poi_creator_50"
    static let helpfulVoter = "helpful_voter"
    static let earlyAdopter = "early_adopter"
    static let communityHero = "community_hero"
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
