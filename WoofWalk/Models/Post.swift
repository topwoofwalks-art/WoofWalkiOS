import Foundation
import FirebaseFirestore

enum PostCategory: String, Codable, CaseIterable {
    case update = "UPDATE"
    case walkHighlight = "WALK_HIGHLIGHT"
    case lostDogAlert = "LOST_DOG_ALERT"
    case dogPhoto = "DOG_PHOTO"
    case challengeProgress = "CHALLENGE_PROGRESS"
    case walkCompletion = "WALK_COMPLETION"
}

struct PostMedia: Codable {
    var url: String
    var type: String // "PHOTO", "VIDEO"
    var width: Int?
    var height: Int?
    var label: String?

    init(url: String = "", type: String = "PHOTO", width: Int? = nil, height: Int? = nil, label: String? = nil) {
        self.url = url; self.type = type; self.width = width; self.height = height; self.label = label
    }
}

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    var authorId: String
    var authorName: String
    var authorAvatar: String?
    var type: String
    var category: String?
    var text: String
    var content: String?
    var caption: String?
    var visibility: String?
    var media: [PostMedia]?
    var locationTag: String?
    var latitude: Double?
    var longitude: Double?
    var createdAt: Timestamp?
    var commentCount: Int
    var comments: Int?
    var likes: Int?
    var shares: Int?
    var reactions: [String: Int]?
    var reactionBy: [String: String]?
    var walkData: WalkData?
    var lostDogData: LostDogData?
    var photoUrl: String?
    var likeCount: Int
    var likedBy: [String]
    var bookmarkedBy: [String]?
    var shareCount: Int?
    var isWalkAutoPost: Bool?
    var routeMapThumbnailUrl: String?
    var challengeId: String?
    var dogIds: [String]?
    var hashtags: [String]?
    var geohash: String?
    var authorStreak: Int?

    init(id: String? = nil, authorId: String = "", authorName: String = "", authorAvatar: String? = nil, type: String = "TEXT", category: String? = nil, text: String = "", content: String? = nil, caption: String? = nil, visibility: String? = "PUBLIC", media: [PostMedia]? = nil, locationTag: String? = nil, latitude: Double? = nil, longitude: Double? = nil, createdAt: Timestamp? = nil, commentCount: Int = 0, comments: Int? = nil, likes: Int? = nil, shares: Int? = nil, reactions: [String: Int]? = nil, reactionBy: [String: String]? = nil, walkData: WalkData? = nil, lostDogData: LostDogData? = nil, photoUrl: String? = nil, likeCount: Int = 0, likedBy: [String] = [], bookmarkedBy: [String]? = nil, shareCount: Int? = nil, isWalkAutoPost: Bool? = nil, routeMapThumbnailUrl: String? = nil, challengeId: String? = nil, dogIds: [String]? = nil, hashtags: [String]? = nil, geohash: String? = nil, authorStreak: Int? = nil) {
        self.id = id; self.authorId = authorId; self.authorName = authorName; self.authorAvatar = authorAvatar; self.type = type; self.category = category; self.text = text; self.content = content; self.caption = caption; self.visibility = visibility; self.media = media; self.locationTag = locationTag; self.latitude = latitude; self.longitude = longitude; self.createdAt = createdAt; self.commentCount = commentCount; self.comments = comments; self.likes = likes; self.shares = shares; self.reactions = reactions; self.reactionBy = reactionBy; self.walkData = walkData; self.lostDogData = lostDogData; self.photoUrl = photoUrl; self.likeCount = likeCount; self.likedBy = likedBy; self.bookmarkedBy = bookmarkedBy; self.shareCount = shareCount; self.isWalkAutoPost = isWalkAutoPost; self.routeMapThumbnailUrl = routeMapThumbnailUrl; self.challengeId = challengeId; self.dogIds = dogIds; self.hashtags = hashtags; self.geohash = geohash; self.authorStreak = authorStreak
    }
}

struct WalkData: Codable {
    var duration: Int
    var distance: Double
    var steps: Int
    var paceMinPerKm: Double?
    var routePoints: [[String: Double]]?
    var achievements: [String]?
    var poiCount: Int?
    var routeAdherence: Double?
    var dogNames: [String]?
    var dogPhotoUrls: [String]?

    init(duration: Int = 0, distance: Double = 0.0, steps: Int = 0, paceMinPerKm: Double? = nil, routePoints: [[String: Double]]? = nil, achievements: [String]? = nil, poiCount: Int? = nil, routeAdherence: Double? = nil, dogNames: [String]? = nil, dogPhotoUrls: [String]? = nil) {
        self.duration = duration; self.distance = distance; self.steps = steps; self.paceMinPerKm = paceMinPerKm; self.routePoints = routePoints; self.achievements = achievements; self.poiCount = poiCount; self.routeAdherence = routeAdherence; self.dogNames = dogNames; self.dogPhotoUrls = dogPhotoUrls
    }
}

struct LostDogData: Codable {
    var dogName: String
    var dogBreed: String
    var dogPhotoUrl: String?
    var lastSeenLocation: String
    var contactInfo: String

    init(dogName: String = "",
         dogBreed: String = "",
         dogPhotoUrl: String? = nil,
         lastSeenLocation: String = "",
         contactInfo: String = "") {
        self.dogName = dogName
        self.dogBreed = dogBreed
        self.dogPhotoUrl = dogPhotoUrl
        self.lastSeenLocation = lastSeenLocation
        self.contactInfo = contactInfo
    }
}

struct PostComment: Identifiable, Codable {
    @DocumentID var id: String?
    var postId: String
    var authorId: String
    var authorName: String
    var text: String
    var createdAt: Timestamp?

    init(id: String? = nil,
         postId: String = "",
         authorId: String = "",
         authorName: String = "",
         text: String = "",
         createdAt: Timestamp? = nil) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.text = text
        self.createdAt = createdAt
    }
}
