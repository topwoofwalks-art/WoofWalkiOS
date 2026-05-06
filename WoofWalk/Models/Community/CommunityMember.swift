import Foundation
import FirebaseFirestore

/// A member of a community. Path:
/// `communities/{communityId}/members/{userId}`. Document id is the user
/// id (deterministic), so `@DocumentID` doubles as the userId.
struct CommunityMember: Identifiable, Codable, Equatable {
    var id: String?
    var userId: String = ""
    var communityId: String = ""
    var displayName: String = ""
    var photoUrl: String?
    var role: CommunityMemberRole = .member
    var dogNames: [String] = []
    var dogBreeds: [String] = []
    var bio: String = ""
    var isMuted: Bool = false
    var isBanned: Bool = false
    var banReason: String?
    var notificationsEnabled: Bool = true
    var postCount: Int = 0
    var commentCount: Int = 0
    var joinedAt: Double = Date().timeIntervalSince1970 * 1000
    var lastActiveAt: Double = Date().timeIntervalSince1970 * 1000

    var canPost: Bool { !isMuted && !isBanned }
    var canModerate: Bool { role.canModerate && !isBanned }
    var canAdmin: Bool { role.canAdmin && !isBanned }
    var isOwner: Bool { role.isOwner }

    enum CodingKeys: String, CodingKey {
        case id
        case userId, communityId
        case displayName, photoUrl
        case role
        case dogNames, dogBreeds, bio
        case isMuted, isBanned, banReason
        case notificationsEnabled
        case postCount, commentCount
        case joinedAt, lastActiveAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
        self.communityId = (try? c.decode(String.self, forKey: .communityId)) ?? ""
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        self.photoUrl = try? c.decode(String.self, forKey: .photoUrl)
        self.role = CommunityMemberRole.from(try? c.decode(String.self, forKey: .role))
        self.dogNames = (try? c.decode([String].self, forKey: .dogNames)) ?? []
        self.dogBreeds = (try? c.decode([String].self, forKey: .dogBreeds)) ?? []
        self.bio = (try? c.decode(String.self, forKey: .bio)) ?? ""
        self.isMuted = (try? c.decode(Bool.self, forKey: .isMuted)) ?? false
        self.isBanned = (try? c.decode(Bool.self, forKey: .isBanned)) ?? false
        self.banReason = try? c.decode(String.self, forKey: .banReason)
        self.notificationsEnabled = (try? c.decode(Bool.self, forKey: .notificationsEnabled)) ?? true
        self.postCount = (try? c.decode(Int.self, forKey: .postCount)) ?? 0
        self.commentCount = (try? c.decode(Int.self, forKey: .commentCount)) ?? 0
        self.joinedAt = Self.decodeMillis(c, key: .joinedAt)
        self.lastActiveAt = Self.decodeMillis(c, key: .lastActiveAt)
    }

    init(
        id: String? = nil,
        userId: String = "",
        communityId: String = "",
        displayName: String = "",
        photoUrl: String? = nil,
        role: CommunityMemberRole = .member,
        dogNames: [String] = [],
        dogBreeds: [String] = [],
        bio: String = "",
        isMuted: Bool = false,
        isBanned: Bool = false,
        banReason: String? = nil,
        notificationsEnabled: Bool = true,
        postCount: Int = 0,
        commentCount: Int = 0,
        joinedAt: Double = Date().timeIntervalSince1970 * 1000,
        lastActiveAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.userId = userId
        self.communityId = communityId
        self.displayName = displayName
        self.photoUrl = photoUrl
        self.role = role
        self.dogNames = dogNames
        self.dogBreeds = dogBreeds
        self.bio = bio
        self.isMuted = isMuted
        self.isBanned = isBanned
        self.banReason = banReason
        self.notificationsEnabled = notificationsEnabled
        self.postCount = postCount
        self.commentCount = commentCount
        self.joinedAt = joinedAt
        self.lastActiveAt = lastActiveAt
    }

    private static func decodeMillis(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double {
        if let n = try? container.decode(Double.self, forKey: key) { return n }
        if let n = try? container.decode(Int64.self, forKey: key) { return Double(n) }
        if let ts = try? container.decode(Timestamp.self, forKey: key) {
            return ts.dateValue().timeIntervalSince1970 * 1000
        }
        return Date().timeIntervalSince1970 * 1000
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "communityId": communityId,
            "displayName": displayName,
            "role": role.rawValue,
            "dogNames": dogNames,
            "dogBreeds": dogBreeds,
            "bio": bio,
            "isMuted": isMuted,
            "isBanned": isBanned,
            "notificationsEnabled": notificationsEnabled,
            "postCount": postCount,
            "commentCount": commentCount,
            "joinedAt": joinedAt,
            "lastActiveAt": lastActiveAt
        ]
        if let photoUrl { data["photoUrl"] = photoUrl }
        if let banReason { data["banReason"] = banReason }
        return data
    }
}
