import Foundation
import FirebaseFirestore

// MARK: - CommunityPostType

enum CommunityPostType: String, Codable, CaseIterable, Identifiable {
    case text = "TEXT"
    case photo = "PHOTO"
    case video = "VIDEO"
    case walkShare = "WALK_SHARE"
    case poll = "POLL"
    case eventAnnouncement = "EVENT_ANNOUNCEMENT"
    case adoptionListing = "ADOPTION_LISTING"
    case walkSchedule = "WALK_SCHEDULE"
    case puppyMilestone = "PUPPY_MILESTONE"
    case trainingTip = "TRAINING_TIP"
    case breedAlert = "BREED_ALERT"
    case destinationReview = "DESTINATION_REVIEW"
    case dietPlan = "DIET_PLAN"
    case competitionEntry = "COMPETITION_ENTRY"
    case pinned = "PINNED"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .photo: return "Photo"
        case .video: return "Video"
        case .walkShare: return "Walk"
        case .poll: return "Poll"
        case .eventAnnouncement: return "Event"
        case .adoptionListing: return "Adoption"
        case .walkSchedule: return "Group Walk"
        case .puppyMilestone: return "Milestone"
        case .trainingTip: return "Training Tip"
        case .breedAlert: return "Breed Alert"
        case .destinationReview: return "Review"
        case .dietPlan: return "Diet Plan"
        case .competitionEntry: return "Competition"
        case .pinned: return "Pinned"
        }
    }

    var iconSystemName: String {
        switch self {
        case .text: return "text.bubble"
        case .photo: return "photo"
        case .video: return "video"
        case .walkShare: return "figure.walk"
        case .poll: return "chart.bar"
        case .eventAnnouncement: return "calendar"
        case .adoptionListing: return "heart"
        case .walkSchedule: return "figure.walk.circle"
        case .puppyMilestone: return "star"
        case .trainingTip: return "graduationcap"
        case .breedAlert: return "exclamationmark.triangle"
        case .destinationReview: return "mappin"
        case .dietPlan: return "fork.knife"
        case .competitionEntry: return "trophy"
        case .pinned: return "pin"
        }
    }

    static func from(_ raw: String?) -> CommunityPostType {
        guard let raw else { return .text }
        return CommunityPostType(rawValue: raw.uppercased()) ?? .text
    }
}

// MARK: - PollOption

struct PollOption: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var text: String = ""
    var voteCount: Int = 0
    var votedBy: [String] = []

    func isVotedBy(_ userId: String) -> Bool { votedBy.contains(userId) }

    func toFirestoreData() -> [String: Any] {
        [
            "id": id,
            "text": text,
            "voteCount": voteCount,
            "votedBy": votedBy
        ]
    }
}

// MARK: - CommunityPost

/// Post within a community. Path:
/// `communities/{communityId}/posts/{postId}`. Mirrors Android's
/// `CommunityPost` data class.
struct CommunityPost: Identifiable, Codable, Equatable {
    var id: String?
    var communityId: String = ""
    var authorId: String = ""
    var authorName: String = ""
    var authorPhotoUrl: String?
    var type: CommunityPostType = .text
    var title: String = ""
    var content: String = ""
    var mediaUrls: [String] = []
    var mediaTypes: [String] = []
    var tags: [String] = []
    var isPinned: Bool = false
    var isEdited: Bool = false
    var isDeleted: Bool = false
    var likeCount: Int = 0
    var commentCount: Int = 0
    var likedBy: [String] = []
    /// Per-reaction-type membership. Keys: "LIKE", "LOVE", "LAUGH",
    /// "HELPFUL", "SAD" — matches the Android ReactionType enum names.
    /// Each value is the list of userIds who reacted with that type.
    /// A user appears in at most one entry; mirrored into `likedBy` for
    /// legacy "did anyone react" reads.
    var reactions: [String: [String]] = [:]
    var bookmarkedBy: [String] = []
    var pollOptions: [PollOption] = []
    var pollEndTime: Double?
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var linkedDogIds: [String] = []
    var metadata: [String: String]?
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    var updatedAt: Double = Date().timeIntervalSince1970 * 1000

    func isLikedBy(_ userId: String) -> Bool { likedBy.contains(userId) }
    func isBookmarkedBy(_ userId: String) -> Bool { bookmarkedBy.contains(userId) }
    var hasMedia: Bool { !mediaUrls.isEmpty }

    /// Returns the upper-case reaction name the user has on this post, or
    /// nil. Matches Android's `userReaction(userId)`.
    func userReaction(userId: String) -> String? {
        reactions.first(where: { (_, users) in users.contains(userId) })?.key
    }

    var isPoll: Bool { type == .poll && !pollOptions.isEmpty }

    var isPollExpired: Bool {
        guard let pollEndTime else { return false }
        return Date().timeIntervalSince1970 * 1000 > pollEndTime
    }

    enum CodingKeys: String, CodingKey {
        case id
        case communityId, authorId, authorName, authorPhotoUrl
        case type, title, content
        case mediaUrls, mediaTypes, tags
        case isPinned, isEdited, isDeleted
        case likeCount, commentCount, likedBy
        case reactions, bookmarkedBy
        case pollOptions, pollEndTime
        case latitude, longitude, locationName
        case linkedDogIds, metadata
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.communityId = (try? c.decode(String.self, forKey: .communityId)) ?? ""
        self.authorId = (try? c.decode(String.self, forKey: .authorId)) ?? ""
        self.authorName = (try? c.decode(String.self, forKey: .authorName)) ?? ""
        self.authorPhotoUrl = try? c.decode(String.self, forKey: .authorPhotoUrl)
        self.type = CommunityPostType.from(try? c.decode(String.self, forKey: .type))
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.content = (try? c.decode(String.self, forKey: .content)) ?? ""
        self.mediaUrls = (try? c.decode([String].self, forKey: .mediaUrls)) ?? []
        self.mediaTypes = (try? c.decode([String].self, forKey: .mediaTypes)) ?? []
        self.tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        self.isPinned = (try? c.decode(Bool.self, forKey: .isPinned)) ?? false
        self.isEdited = (try? c.decode(Bool.self, forKey: .isEdited)) ?? false
        self.isDeleted = (try? c.decode(Bool.self, forKey: .isDeleted)) ?? false
        self.likeCount = (try? c.decode(Int.self, forKey: .likeCount)) ?? 0
        self.commentCount = (try? c.decode(Int.self, forKey: .commentCount)) ?? 0
        self.likedBy = (try? c.decode([String].self, forKey: .likedBy)) ?? []
        self.reactions = (try? c.decode([String: [String]].self, forKey: .reactions)) ?? [:]
        self.bookmarkedBy = (try? c.decode([String].self, forKey: .bookmarkedBy)) ?? []
        self.pollOptions = (try? c.decode([PollOption].self, forKey: .pollOptions)) ?? []
        self.pollEndTime = try? c.decode(Double.self, forKey: .pollEndTime)
        self.latitude = try? c.decode(Double.self, forKey: .latitude)
        self.longitude = try? c.decode(Double.self, forKey: .longitude)
        self.locationName = try? c.decode(String.self, forKey: .locationName)
        self.linkedDogIds = (try? c.decode([String].self, forKey: .linkedDogIds)) ?? []
        self.metadata = try? c.decode([String: String].self, forKey: .metadata)
        self.createdAt = Self.decodeMillis(c, key: .createdAt)
        self.updatedAt = Self.decodeMillis(c, key: .updatedAt)
    }

    init(
        id: String? = nil,
        communityId: String = "",
        authorId: String = "",
        authorName: String = "",
        authorPhotoUrl: String? = nil,
        type: CommunityPostType = .text,
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
        reactions: [String: [String]] = [:],
        bookmarkedBy: [String] = [],
        pollOptions: [PollOption] = [],
        pollEndTime: Double? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil,
        linkedDogIds: [String] = [],
        metadata: [String: String]? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000,
        updatedAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
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
        self.reactions = reactions
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
            "communityId": communityId,
            "authorId": authorId,
            "authorName": authorName,
            "type": type.rawValue,
            "title": title,
            "content": content,
            "mediaUrls": mediaUrls,
            "mediaTypes": mediaTypes,
            "tags": tags,
            "isPinned": isPinned,
            "isEdited": isEdited,
            "isDeleted": isDeleted,
            "likeCount": likeCount,
            "commentCount": commentCount,
            "likedBy": likedBy,
            "reactions": reactions,
            "bookmarkedBy": bookmarkedBy,
            "pollOptions": pollOptions.map { $0.toFirestoreData() },
            "linkedDogIds": linkedDogIds,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        if let authorPhotoUrl { data["authorPhotoUrl"] = authorPhotoUrl }
        if let pollEndTime { data["pollEndTime"] = pollEndTime }
        if let latitude { data["latitude"] = latitude }
        if let longitude { data["longitude"] = longitude }
        if let locationName { data["locationName"] = locationName }
        if let metadata { data["metadata"] = metadata }
        return data
    }
}

// MARK: - Reaction types

/// Five typed reactions matching Android's `ReactionType` enum. Persisted
/// in `CommunityPost.reactions` as keys (uppercase rawValue).
enum CommunityReactionType: String, CaseIterable, Identifiable {
    case like = "LIKE"
    case love = "LOVE"
    case laugh = "LAUGH"
    case helpful = "HELPFUL"
    case sad = "SAD"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .like: return "👍"
        case .love: return "❤️"
        case .laugh: return "😂"
        case .helpful: return "💡"
        case .sad: return "😢"
        }
    }

    var label: String {
        switch self {
        case .like: return "Like"
        case .love: return "Love"
        case .laugh: return "Laugh"
        case .helpful: return "Helpful"
        case .sad: return "Sad"
        }
    }
}
