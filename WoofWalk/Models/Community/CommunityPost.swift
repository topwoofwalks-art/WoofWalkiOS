import Foundation
import FirebaseFirestore

// MARK: - Community Post Type

enum CommunityPostType: String, Codable, CaseIterable {
    case TEXT
    case PHOTO
    case VIDEO
    case WALK_SHARE
    case POLL
    case EVENT_ANNOUNCEMENT
    case ADOPTION_LISTING
    case WALK_SCHEDULE
    case PUPPY_MILESTONE
    case TRAINING_TIP
    case BREED_ALERT
    case DESTINATION_REVIEW
    case DIET_PLAN
    case COMPETITION_ENTRY
    case PINNED
}

// MARK: - Poll Option

struct PollOption: Identifiable, Codable {
    var id: String
    var text: String
    var voteCount: Int
    var votedBy: [String]

    init(id: String = UUID().uuidString,
         text: String = "",
         voteCount: Int = 0,
         votedBy: [String] = []) {
        self.id = id
        self.text = text
        self.voteCount = voteCount
        self.votedBy = votedBy
    }

    func isVotedBy(userId: String) -> Bool {
        return votedBy.contains(userId)
    }
}

// MARK: - Community Post

/// Firestore path: communities/{communityId}/posts/{postId}
struct CommunityPost: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var authorId: String
    var authorName: String
    var authorPhotoUrl: String?
    var type: String
    var title: String
    var content: String
    var mediaUrls: [String]
    var mediaTypes: [String]
    var tags: [String]
    var isPinned: Bool
    var isEdited: Bool
    var isDeleted: Bool
    var likeCount: Int
    var commentCount: Int
    var likedBy: [String]
    var bookmarkedBy: [String]
    var pollOptions: [PollOption]
    var pollEndTime: Double?
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var linkedDogIds: [String]
    var metadata: [String: String]?
    var createdAt: Double
    var updatedAt: Double

    init(id: String? = nil,
         communityId: String = "",
         authorId: String = "",
         authorName: String = "",
         authorPhotoUrl: String? = nil,
         type: String = CommunityPostType.TEXT.rawValue,
         title: String = "",
         content: String = "",
         mediaUrls: [String] = [],
         mediaTypes: [String] = [],
         tags: [String] = [],
         isPinned: Bool = false,
         isEdited: Bool = false,
         isDeleted: Bool = false,
         likeCount: Int = 0,
         commentCount: Int = 0,
         likedBy: [String] = [],
         bookmarkedBy: [String] = [],
         pollOptions: [PollOption] = [],
         pollEndTime: Double? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         locationName: String? = nil,
         linkedDogIds: [String] = [],
         metadata: [String: String]? = nil,
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         updatedAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.authorId = authorId
        self.authorName = authorName
        self.authorPhotoUrl = authorPhotoUrl
        self.type = type
        self.title = title
        self.content = content
        self.mediaUrls = mediaUrls
        self.mediaTypes = mediaTypes
        self.tags = tags
        self.isPinned = isPinned
        self.isEdited = isEdited
        self.isDeleted = isDeleted
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.likedBy = likedBy
        self.bookmarkedBy = bookmarkedBy
        self.pollOptions = pollOptions
        self.pollEndTime = pollEndTime
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.linkedDogIds = linkedDogIds
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func getPostType() -> CommunityPostType {
        return CommunityPostType(rawValue: type) ?? .TEXT
    }

    func isLikedBy(userId: String) -> Bool {
        return likedBy.contains(userId)
    }

    func isBookmarkedBy(userId: String) -> Bool {
        return bookmarkedBy.contains(userId)
    }

    func hasMedia() -> Bool {
        return !mediaUrls.isEmpty
    }

    func isPoll() -> Bool {
        return getPostType() == .POLL && !pollOptions.isEmpty
    }

    func isPollExpired() -> Bool {
        guard let endTime = pollEndTime else { return false }
        return Date().timeIntervalSince1970 * 1000 > endTime
    }
}

// MARK: - Community Comment

/// Firestore path: communities/{communityId}/posts/{postId}/comments/{commentId}
struct CommunityComment: Identifiable, Codable {
    @DocumentID var id: String?
    var postId: String
    var communityId: String
    var authorId: String
    var authorName: String
    var authorPhotoUrl: String?
    var content: String
    var parentCommentId: String?
    var isEdited: Bool
    var isDeleted: Bool
    var likeCount: Int
    var likedBy: [String]
    var replyCount: Int
    var mediaUrl: String?
    var mediaType: String?
    var createdAt: Double
    var updatedAt: Double

    init(id: String? = nil,
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
         updatedAt: Double = Date().timeIntervalSince1970 * 1000) {
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

    func isReply() -> Bool {
        return parentCommentId != nil
    }

    func isLikedBy(userId: String) -> Bool {
        return likedBy.contains(userId)
    }

    func hasMedia() -> Bool {
        return mediaUrl != nil
    }
}

// MARK: - Community Event

/// Firestore path: communities/{communityId}/events/{eventId}
struct CommunityEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var title: String
    var description: String
    var createdBy: String
    var creatorName: String
    var latitude: Double?
    var longitude: Double?
    var locationName: String
    var geohash: String?
    var startTime: Double
    var endTime: Double?
    var attendeeIds: [String]
    var maxAttendees: Int?
    var coverPhotoUrl: String?
    var tags: [String]
    var isCancelled: Bool
    var isRecurring: Bool
    var recurrenceRule: String?
    var createdAt: Double
    var updatedAt: Double

    init(id: String? = nil,
         communityId: String = "",
         title: String = "",
         description: String = "",
         createdBy: String = "",
         creatorName: String = "",
         latitude: Double? = nil,
         longitude: Double? = nil,
         locationName: String = "",
         geohash: String? = nil,
         startTime: Double = Date().timeIntervalSince1970 * 1000,
         endTime: Double? = nil,
         attendeeIds: [String] = [],
         maxAttendees: Int? = nil,
         coverPhotoUrl: String? = nil,
         tags: [String] = [],
         isCancelled: Bool = false,
         isRecurring: Bool = false,
         recurrenceRule: String? = nil,
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         updatedAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.title = title
        self.description = description
        self.createdBy = createdBy
        self.creatorName = creatorName
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.geohash = geohash
        self.startTime = startTime
        self.endTime = endTime
        self.attendeeIds = attendeeIds
        self.maxAttendees = maxAttendees
        self.coverPhotoUrl = coverPhotoUrl
        self.tags = tags
        self.isCancelled = isCancelled
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func isFull() -> Bool {
        guard let max = maxAttendees else { return false }
        return attendeeIds.count >= max
    }

    func isAttending(userId: String) -> Bool {
        return attendeeIds.contains(userId)
    }

    func isPast() -> Bool {
        return Date().timeIntervalSince1970 * 1000 > startTime
    }
}
