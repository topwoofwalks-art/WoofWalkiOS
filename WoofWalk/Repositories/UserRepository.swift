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

    func addFriend(friendUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let connectionId = userId < friendUserId ? "\(userId)_\(friendUserId)" : "\(friendUserId)_\(userId)"
        let connection: [String: Any] = [
            "user1": min(userId, friendUserId),
            "user2": max(userId, friendUserId),
            "createdAt": FieldValue.serverTimestamp(),
            "status": "active"
        ]

        try await db.collection("connections").document(connectionId).setData(connection)
    }

    func removeFriend(friendUserId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "UserRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let connectionId = userId < friendUserId ? "\(userId)_\(friendUserId)" : "\(friendUserId)_\(userId)"
        try await db.collection("connections").document(connectionId).delete()
    }

    func getFriends() -> AnyPublisher<[UserProfile], Error> {
        guard let userId = auth.currentUser?.uid else {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        let publisher = PassthroughSubject<[UserProfile], Error>()

        db.collection("connections")
            .whereField("status", isEqualTo: "active")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    publisher.send(completion: .failure(error))
                    return
                }

                guard let self = self, let snapshot = snapshot else {
                    publisher.send([])
                    return
                }

                var friendIds = Set<String>()

                for doc in snapshot.documents {
                    let data = doc.data()
                    if let user1 = data["user1"] as? String, let user2 = data["user2"] as? String {
                        if user1 == userId {
                            friendIds.insert(user2)
                        } else if user2 == userId {
                            friendIds.insert(user1)
                        }
                    }
                }

                Task {
                    do {
                        if friendIds.isEmpty {
                            publisher.send([])
                        } else {
                            var users: [UserProfile] = []
                            for chunk in Array(friendIds).chunked(into: 10) {
                                let snapshot = try await self.db.collection("users")
                                    .whereField("id", in: chunk)
                                    .getDocuments()

                                let chunkUsers = try snapshot.documents.compactMap { try $0.data(as: UserProfile.self) }
                                users.append(contentsOf: chunkUsers)
                            }
                            publisher.send(users)
                        }
                    } catch {
                        publisher.send(completion: .failure(error))
                    }
                }
            }

        return publisher.eraseToAnyPublisher()
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
