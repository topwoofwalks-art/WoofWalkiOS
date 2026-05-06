import Foundation
import FirebaseFirestore

/// A comment on a community post. Path:
/// `communities/{communityId}/posts/{postId}/comments/{commentId}`. Comments
/// thread via `parentCommentId` — a top-level comment has nil here, a reply
/// references its parent.
struct CommunityComment: Identifiable, Codable, Equatable {
    var id: String?
    var postId: String = ""
    var communityId: String = ""
    var authorId: String = ""
    var authorName: String = ""
    var authorPhotoUrl: String?
    var content: String = ""
    var parentCommentId: String?
    var isEdited: Bool = false
    var isDeleted: Bool = false
    var likeCount: Int = 0
    var likedBy: [String] = []
    var replyCount: Int = 0
    var mediaUrl: String?
    var mediaType: String?
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    var updatedAt: Double = Date().timeIntervalSince1970 * 1000

    var isReply: Bool { parentCommentId != nil }
    func isLikedBy(_ userId: String) -> Bool { likedBy.contains(userId) }
    var hasMedia: Bool { mediaUrl != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case postId, communityId
        case authorId, authorName, authorPhotoUrl
        case content, parentCommentId
        case isEdited, isDeleted
        case likeCount, likedBy, replyCount
        case mediaUrl, mediaType
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.postId = (try? c.decode(String.self, forKey: .postId)) ?? ""
        self.communityId = (try? c.decode(String.self, forKey: .communityId)) ?? ""
        self.authorId = (try? c.decode(String.self, forKey: .authorId)) ?? ""
        self.authorName = (try? c.decode(String.self, forKey: .authorName)) ?? ""
        self.authorPhotoUrl = try? c.decode(String.self, forKey: .authorPhotoUrl)
        self.content = (try? c.decode(String.self, forKey: .content)) ?? ""
        self.parentCommentId = try? c.decode(String.self, forKey: .parentCommentId)
        self.isEdited = (try? c.decode(Bool.self, forKey: .isEdited)) ?? false
        self.isDeleted = (try? c.decode(Bool.self, forKey: .isDeleted)) ?? false
        self.likeCount = (try? c.decode(Int.self, forKey: .likeCount)) ?? 0
        self.likedBy = (try? c.decode([String].self, forKey: .likedBy)) ?? []
        self.replyCount = (try? c.decode(Int.self, forKey: .replyCount)) ?? 0
        self.mediaUrl = try? c.decode(String.self, forKey: .mediaUrl)
        self.mediaType = try? c.decode(String.self, forKey: .mediaType)
        self.createdAt = Self.decodeMillis(c, key: .createdAt)
        self.updatedAt = Self.decodeMillis(c, key: .updatedAt)
    }

    init(
        id: String? = nil,
        postId: String = "",
        communityId: String = "",
        authorId: String = "",
        authorName: String = "",
        authorPhotoUrl: String? = nil,
        content: String = "",
        parentCommentId: String? = nil,
        isEdited: Bool = false,
        isDeleted: Bool = false,
        likeCount: Int = 0,
        likedBy: [String] = [],
        replyCount: Int = 0,
        mediaUrl: String? = nil,
        mediaType: String? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000,
        updatedAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.postId = postId
        self.communityId = communityId
        self.authorId = authorId
        self.authorName = authorName
        self.authorPhotoUrl = authorPhotoUrl
        self.content = content
        self.parentCommentId = parentCommentId
        self.isEdited = isEdited
        self.isDeleted = isDeleted
        self.likeCount = likeCount
        self.likedBy = likedBy
        self.replyCount = replyCount
        self.mediaUrl = mediaUrl
        self.mediaType = mediaType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
            "postId": postId,
            "communityId": communityId,
            "authorId": authorId,
            "authorName": authorName,
            "content": content,
            "isEdited": isEdited,
            "isDeleted": isDeleted,
            "likeCount": likeCount,
            "likedBy": likedBy,
            "replyCount": replyCount,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        if let authorPhotoUrl { data["authorPhotoUrl"] = authorPhotoUrl }
        if let parentCommentId { data["parentCommentId"] = parentCommentId }
        if let mediaUrl { data["mediaUrl"] = mediaUrl }
        if let mediaType { data["mediaType"] = mediaType }
        return data
    }
}
