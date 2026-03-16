import Foundation
import FirebaseFirestore
import CoreLocation

struct Friend: Identifiable, Codable {
    @DocumentID var id: String?
    var userId1: String
    var userId2: String
    var status: String
    var requestedBy: String
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var acceptedAt: Timestamp?

    init(id: String? = nil,
         userId1: String = "",
         userId2: String = "",
         status: String = FriendStatus.pending.rawValue,
         requestedBy: String = "",
         createdAt: Timestamp? = nil,
         acceptedAt: Timestamp? = nil) {
        self.id = id
        self.userId1 = userId1
        self.userId2 = userId2
        self.status = status
        self.requestedBy = requestedBy
        self.createdAt = createdAt
        self.acceptedAt = acceptedAt
    }

    func getFriendStatus() -> FriendStatus {
        return FriendStatus(rawValue: status) ?? .pending
    }

    func getOtherUserId(currentUserId: String) -> String {
        return userId1 == currentUserId ? userId2 : userId1
    }
}

enum FriendStatus: String, Codable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case blocked = "BLOCKED"
}

struct Event: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var location: GeoPoint?
    var locationName: String
    var geohash: String
    var datetime: Timestamp?
    var createdBy: String
    var creatorName: String
    var attendees: [String]
    var maxAttendees: Int
    var difficulty: String
    var distanceKm: Double
    var tags: [String]
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
    var photoUrl: String?
    var cancelled: Bool

    init(id: String? = nil,
         title: String = "",
         description: String = "",
         location: GeoPoint? = nil,
         locationName: String = "",
         geohash: String = "",
         datetime: Timestamp? = nil,
         createdBy: String = "",
         creatorName: String = "",
         attendees: [String] = [],
         maxAttendees: Int = 20,
         difficulty: String = "EASY",
         distanceKm: Double = 0.0,
         tags: [String] = [],
         createdAt: Timestamp? = nil,
         updatedAt: Timestamp? = nil,
         photoUrl: String? = nil,
         cancelled: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.location = location
        self.locationName = locationName
        self.geohash = geohash
        self.datetime = datetime
        self.createdBy = createdBy
        self.creatorName = creatorName
        self.attendees = attendees
        self.maxAttendees = maxAttendees
        self.difficulty = difficulty
        self.distanceKm = distanceKm
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.photoUrl = photoUrl
        self.cancelled = cancelled
    }

    func isFull() -> Bool {
        return attendees.count >= maxAttendees
    }

    func isAttending(userId: String) -> Bool {
        return attendees.contains(userId)
    }
}

struct Chat: Identifiable, Codable {
    @DocumentID var id: String?
    var participantIds: [String]
    var participantNames: [String: String]
    var participantPhotos: [String: String]
    var lastMessage: String
    var lastMessageSenderId: String
    @ServerTimestamp var lastMessageAt: Timestamp?
    var unreadCount: [String: Int]
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?

    init(id: String? = nil,
         participantIds: [String] = [],
         participantNames: [String: String] = [:],
         participantPhotos: [String: String] = [:],
         lastMessage: String = "",
         lastMessageSenderId: String = "",
         lastMessageAt: Timestamp? = nil,
         unreadCount: [String: Int] = [:],
         createdAt: Timestamp? = nil,
         updatedAt: Timestamp? = nil) {
        self.id = id
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.participantPhotos = participantPhotos
        self.lastMessage = lastMessage
        self.lastMessageSenderId = lastMessageSenderId
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func getOtherParticipantId(currentUserId: String) -> String? {
        return participantIds.first { $0 != currentUserId }
    }

    func getOtherParticipantName(currentUserId: String) -> String? {
        guard let participantId = getOtherParticipantId(currentUserId: currentUserId) else { return nil }
        return participantNames[participantId]
    }

    func getOtherParticipantPhoto(currentUserId: String) -> String? {
        guard let participantId = getOtherParticipantId(currentUserId: currentUserId) else { return nil }
        return participantPhotos[participantId]
    }

    func getUnreadCount(userId: String) -> Int {
        return unreadCount[userId] ?? 0
    }
}

struct ChatMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var chatId: String
    var senderId: String
    var senderName: String
    var text: String
    var imageUrl: String?
    var readBy: [String]
    var isAutoReply: Bool
    var type: String?
    @ServerTimestamp var createdAt: Timestamp?

    init(id: String? = nil,
         chatId: String = "",
         senderId: String = "",
         senderName: String = "",
         text: String = "",
         imageUrl: String? = nil,
         readBy: [String] = [],
         isAutoReply: Bool = false,
         type: String? = nil,
         createdAt: Timestamp? = nil) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.imageUrl = imageUrl
        self.readBy = readBy
        self.isAutoReply = isAutoReply
        self.type = type
        self.createdAt = createdAt
    }

    func isReadBy(userId: String) -> Bool {
        return readBy.contains(userId)
    }
}
