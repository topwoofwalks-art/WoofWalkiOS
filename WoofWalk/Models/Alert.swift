#if false
// DISABLED: Duplicate LostDog, PublicDog, Notification types - real versions in MapAnnotation.swift etc.
import Foundation
import FirebaseFirestore

struct LostDog: Identifiable, Codable {
    @DocumentID var id: String?
    var dogId: String
    var dogName: String
    var dogPhotoUrl: String?
    var dogBreed: String
    var reportedBy: String
    var reporterName: String
    var reporterPhone: String?
    var lat: Double
    var lng: Double
    var geohash: String
    var locationDescription: String
    var description: String
    var status: String
    @ServerTimestamp var reportedAt: Timestamp?
    @ServerTimestamp var foundAt: Timestamp?
    @ServerTimestamp var expiresAt: Timestamp?
    var alertRadiusKm: Double

    init(id: String? = nil,
         dogId: String = "",
         dogName: String = "",
         dogPhotoUrl: String? = nil,
         dogBreed: String = "",
         reportedBy: String = "",
         reporterName: String = "",
         reporterPhone: String? = nil,
         lat: Double = 0.0,
         lng: Double = 0.0,
         geohash: String = "",
         locationDescription: String = "",
         description: String = "",
         status: String = LostDogStatus.lost.rawValue,
         reportedAt: Timestamp? = nil,
         foundAt: Timestamp? = nil,
         expiresAt: Timestamp? = nil,
         alertRadiusKm: Double = 5.0) {
        self.id = id
        self.dogId = dogId
        self.dogName = dogName
        self.dogPhotoUrl = dogPhotoUrl
        self.dogBreed = dogBreed
        self.reportedBy = reportedBy
        self.reporterName = reporterName
        self.reporterPhone = reporterPhone
        self.lat = lat
        self.lng = lng
        self.geohash = geohash
        self.locationDescription = locationDescription
        self.description = description
        self.status = status
        self.reportedAt = reportedAt
        self.foundAt = foundAt
        self.expiresAt = expiresAt
        self.alertRadiusKm = alertRadiusKm
    }

    func getStatus() -> LostDogStatus {
        return LostDogStatus(rawValue: status) ?? .lost
    }

    func isActive() -> Bool {
        return status == LostDogStatus.lost.rawValue
    }
}

enum LostDogStatus: String, Codable {
    case lost = "LOST"
    case found = "FOUND"
    case expired = "EXPIRED"
}

struct PublicDog: Identifiable, Codable {
    @DocumentID var id: String?
    var dogId: String
    var ownerId: String
    var ownerName: String
    var dogName: String
    var dogPhotoUrl: String?
    var dogBreed: String
    var nervousDog: Bool
    var warningNote: String?
    var currentLat: Double
    var currentLng: Double
    var geohash: String
    var walkId: String
    @ServerTimestamp var lastUpdated: Timestamp?

    init(id: String? = nil,
         dogId: String = "",
         ownerId: String = "",
         ownerName: String = "",
         dogName: String = "",
         dogPhotoUrl: String? = nil,
         dogBreed: String = "",
         nervousDog: Bool = false,
         warningNote: String? = nil,
         currentLat: Double = 0.0,
         currentLng: Double = 0.0,
         geohash: String = "",
         walkId: String = "",
         lastUpdated: Timestamp? = nil) {
        self.id = id
        self.dogId = dogId
        self.ownerId = ownerId
        self.ownerName = ownerName
        self.dogName = dogName
        self.dogPhotoUrl = dogPhotoUrl
        self.dogBreed = dogBreed
        self.nervousDog = nervousDog
        self.warningNote = warningNote
        self.currentLat = currentLat
        self.currentLng = currentLng
        self.geohash = geohash
        self.walkId = walkId
        self.lastUpdated = lastUpdated
    }

    func hasWarning() -> Bool {
        return nervousDog || !(warningNote?.isEmpty ?? true)
    }
}

struct AppNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var type: String
    var title: String
    var body: String
    var read: Bool
    @ServerTimestamp var createdAt: Timestamp?
    var metadata: [String: String]
    var actionUrl: String?
    var iconUrl: String?

    init(id: String? = nil,
         userId: String = "",
         type: String = NotificationType.info.rawValue,
         title: String = "",
         body: String = "",
         read: Bool = false,
         createdAt: Timestamp? = nil,
         metadata: [String: String] = [:],
         actionUrl: String? = nil,
         iconUrl: String? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.body = body
        self.read = read
        self.createdAt = createdAt
        self.metadata = metadata
        self.actionUrl = actionUrl
        self.iconUrl = iconUrl
    }

    func getType() -> NotificationType {
        return NotificationType(rawValue: type) ?? .info
    }
}

enum NotificationType: String, Codable {
    case friendRequest = "FRIEND_REQUEST"
    case friendAccepted = "FRIEND_ACCEPTED"
    case eventInvite = "EVENT_INVITE"
    case eventReminder = "EVENT_REMINDER"
    case eventCancelled = "EVENT_CANCELLED"
    case postLike = "POST_LIKE"
    case postComment = "POST_COMMENT"
    case achievement = "ACHIEVEMENT"
    case alert = "ALERT"
    case info = "INFO"
    case lostDogAlert = "LOST_DOG_ALERT"
    case chatMessage = "CHAT_MESSAGE"
}
#endif
