import Foundation
import FirebaseFirestore

struct PhotoComment: Identifiable, Codable {
    var id: String
    var postId: String
    var photoIndex: Int
    var userId: String
    var userName: String
    var userAvatar: String?
    var text: String
    var timestamp: Int64
    var likes: Int
    var likedBy: [String]

    init(id: String = UUID().uuidString, postId: String = "", photoIndex: Int = 0, userId: String = "", userName: String = "", userAvatar: String? = nil, text: String = "", timestamp: Int64 = 0, likes: Int = 0, likedBy: [String] = []) {
        self.id = id; self.postId = postId; self.photoIndex = photoIndex; self.userId = userId; self.userName = userName; self.userAvatar = userAvatar; self.text = text; self.timestamp = timestamp; self.likes = likes; self.likedBy = likedBy
    }
}

struct Story: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var userAvatar: String?
    var mediaUrl: String
    var mediaType: String // "PHOTO", "VIDEO", "WALK_HIGHLIGHT", "DOG_MOMENT"
    var thumbnailUrl: String?
    var caption: String
    @ServerTimestamp var createdAt: Timestamp?
    var expiresAt: Timestamp?
    var viewedBy: [String]
    var latitude: Double?
    var longitude: Double?

    init(id: String? = nil, userId: String = "", userName: String = "", userAvatar: String? = nil, mediaUrl: String = "", mediaType: String = "PHOTO", thumbnailUrl: String? = nil, caption: String = "", createdAt: Timestamp? = nil, expiresAt: Timestamp? = nil, viewedBy: [String] = [], latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id; self.userId = userId; self.userName = userName; self.userAvatar = userAvatar; self.mediaUrl = mediaUrl; self.mediaType = mediaType; self.thumbnailUrl = thumbnailUrl; self.caption = caption; self.createdAt = createdAt; self.expiresAt = expiresAt; self.viewedBy = viewedBy; self.latitude = latitude; self.longitude = longitude
    }
}

struct StoryGroup: Identifiable {
    var userId: String
    var userName: String
    var userAvatar: String?
    var stories: [Story]
    var hasUnviewed: Bool
    var latestTimestamp: Int64
    var distanceMeters: Double?

    var id: String { userId }
}

struct FeedPreferences: Codable {
    var userId: String
    var showWalkPosts: Bool
    var showLostDogPosts: Bool
    var showTextPosts: Bool
    var showPhotoPosts: Bool
    var mutedUsers: [String]
    var mutedHashtags: [String]
    var followedHashtags: [String]
    var updatedAt: Timestamp?

    init(userId: String = "", showWalkPosts: Bool = true, showLostDogPosts: Bool = true, showTextPosts: Bool = true, showPhotoPosts: Bool = true, mutedUsers: [String] = [], mutedHashtags: [String] = [], followedHashtags: [String] = [], updatedAt: Timestamp? = nil) {
        self.userId = userId; self.showWalkPosts = showWalkPosts; self.showLostDogPosts = showLostDogPosts; self.showTextPosts = showTextPosts; self.showPhotoPosts = showPhotoPosts; self.mutedUsers = mutedUsers; self.mutedHashtags = mutedHashtags; self.followedHashtags = followedHashtags; self.updatedAt = updatedAt
    }
}

struct TrendingTopic: Identifiable {
    var hashtag: String
    var count: Int
    var lastUpdated: Timestamp?
    var region: String?

    var id: String { hashtag }
}
