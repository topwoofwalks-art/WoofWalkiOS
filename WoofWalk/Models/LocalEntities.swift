#if false
// DISABLED: Duplicate SwiftData entities - real versions are in Database/Entities/ and Models/WalkModels.swift
import Foundation
import SwiftData
import FirebaseFirestore

@Model
class WalkSessionEntity {
    @Attribute(.unique) var sessionId: String
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var durationSec: Int64
    var avgPaceSecPerKm: Double?
    var notes: String?

    init(sessionId: String,
         startedAt: Date,
         endedAt: Date? = nil,
         distanceMeters: Double,
         durationSec: Int64,
         avgPaceSecPerKm: Double? = nil,
         notes: String? = nil) {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.durationSec = durationSec
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.notes = notes
    }
}

@Model
class TrackPointEntity {
    @Attribute(.unique) var id: String
    var sessionId: String
    var lat: Double
    var lng: Double
    var accMeters: Float?
    var t: Int64

    init(id: String = UUID().uuidString,
         sessionId: String,
         lat: Double,
         lng: Double,
         accMeters: Float? = nil,
         t: Int64) {
        self.id = id
        self.sessionId = sessionId
        self.lat = lat
        self.lng = lng
        self.accMeters = accMeters
        self.t = t
    }
}

@Model
class WeightLogEntity {
    var dogId: String
    var loggedAt: Date
    var weightKg: Double

    init(dogId: String, loggedAt: Date, weightKg: Double) {
        self.dogId = dogId
        self.loggedAt = loggedAt
        self.weightKg = weightKg
    }
}

@Model
class UserEntity {
    @Attribute(.unique) var id: String
    var username: String
    var email: String
    var photoUrl: String?
    var pawPoints: Int
    var level: Int
    var badgesJson: String
    var dogsJson: String
    var createdAt: Date
    var regionCode: String
    var lastSyncedAt: Date

    init(id: String,
         username: String,
         email: String,
         photoUrl: String? = nil,
         pawPoints: Int,
         level: Int,
         badgesJson: String,
         dogsJson: String,
         createdAt: Date,
         regionCode: String,
         lastSyncedAt: Date) {
        self.id = id
        self.username = username
        self.email = email
        self.photoUrl = photoUrl
        self.pawPoints = pawPoints
        self.level = level
        self.badgesJson = badgesJson
        self.dogsJson = dogsJson
        self.createdAt = createdAt
        self.regionCode = regionCode
        self.lastSyncedAt = lastSyncedAt
    }

    func toDomain() -> UserProfile {
        let badges: [String] = (try? JSONDecoder().decode([String].self, from: badgesJson.data(using: .utf8) ?? Data())) ?? []
        let dogs: [DogProfile] = (try? JSONDecoder().decode([DogProfile].self, from: dogsJson.data(using: .utf8) ?? Data())) ?? []

        return UserProfile(
            id: id,
            username: username,
            email: email,
            photoUrl: photoUrl,
            pawPoints: pawPoints,
            level: level,
            badges: badges,
            dogs: dogs,
            createdAt: nil,
            regionCode: regionCode
        )
    }

    static func fromDomain(_ user: UserProfile) -> UserEntity {
        let badgesJson = (try? JSONEncoder().encode(user.badges)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let dogsJson = (try? JSONEncoder().encode(user.dogs)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return UserEntity(
            id: user.id ?? UUID().uuidString,
            username: user.username,
            email: user.email,
            photoUrl: user.photoUrl,
            pawPoints: user.pawPoints,
            level: user.level,
            badgesJson: badgesJson,
            dogsJson: dogsJson,
            createdAt: user.createdAt?.dateValue() ?? Date(),
            regionCode: user.regionCode,
            lastSyncedAt: Date()
        )
    }
}

@Model
class WalkEntity {
    @Attribute(.unique) var id: String
    var userId: String
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Int
    var durationSec: Int
    var trackJson: String
    var polyline: String
    var dogIdsJson: String
    var syncedToFirestore: Bool

    init(id: String,
         userId: String,
         startedAt: Date,
         endedAt: Date? = nil,
         distanceMeters: Int,
         durationSec: Int,
         trackJson: String,
         polyline: String,
         dogIdsJson: String = "[]",
         syncedToFirestore: Bool = false) {
        self.id = id
        self.userId = userId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.durationSec = durationSec
        self.trackJson = trackJson
        self.polyline = polyline
        self.dogIdsJson = dogIdsJson
        self.syncedToFirestore = syncedToFirestore
    }

    func toDomain() -> WalkHistory {
        let trackPoints: [TrackPoint] = (try? JSONDecoder().decode([TrackPoint].self, from: trackJson.data(using: .utf8) ?? Data())) ?? []
        let dogIds: [String] = (try? JSONDecoder().decode([String].self, from: dogIdsJson.data(using: .utf8) ?? Data())) ?? []

        return WalkHistory(
            id: id,
            userId: userId,
            startedAt: nil,
            endedAt: nil,
            distanceMeters: distanceMeters,
            durationSec: durationSec,
            track: trackPoints,
            polyline: polyline,
            dogIds: dogIds
        )
    }

    static func fromDomain(_ walk: WalkHistory, syncedToFirestore: Bool = false) -> WalkEntity {
        let trackJson = (try? JSONEncoder().encode(walk.track)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let dogIdsJson = (try? JSONEncoder().encode(walk.dogIds)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return WalkEntity(
            id: walk.id ?? UUID().uuidString,
            userId: walk.userId,
            startedAt: walk.startedAt?.dateValue() ?? Date(),
            endedAt: walk.endedAt?.dateValue(),
            distanceMeters: walk.distanceMeters,
            durationSec: walk.durationSec,
            trackJson: trackJson,
            polyline: walk.polyline,
            dogIdsJson: dogIdsJson,
            syncedToFirestore: syncedToFirestore
        )
    }
}

@Model
class DogEntity {
    @Attribute(.unique) var dogId: String
    var ownerUid: String?
    var name: String
    var breed: String?
    var birthdateEpochDays: Int?
    var sex: String?
    var color: String?
    var photoUrl: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var nervousDog: Bool
    var warningNote: String?

    init(dogId: String,
         ownerUid: String? = nil,
         name: String,
         breed: String? = nil,
         birthdateEpochDays: Int? = nil,
         sex: String? = nil,
         color: String? = nil,
         photoUrl: String? = nil,
         createdAt: Date,
         updatedAt: Date,
         isArchived: Bool = false,
         nervousDog: Bool = false,
         warningNote: String? = nil) {
        self.dogId = dogId
        self.ownerUid = ownerUid
        self.name = name
        self.breed = breed
        self.birthdateEpochDays = birthdateEpochDays
        self.sex = sex
        self.color = color
        self.photoUrl = photoUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.nervousDog = nervousDog
        self.warningNote = warningNote
    }

    func toDogProfile() -> DogProfile {
        var age = 0
        if let epochDays = birthdateEpochDays {
            let birthdate = Calendar.current.date(byAdding: .day, value: epochDays, to: Date(timeIntervalSince1970: 0))
            if let birthdate = birthdate {
                age = Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year ?? 0
            }
        }

        return DogProfile(
            id: dogId,
            name: name,
            breed: breed ?? "Mixed",
            age: age,
            photoUrl: photoUrl,
            temperament: "Friendly",
            nervousDog: nervousDog,
            warningNote: warningNote
        )
    }
}

@Model
class PoiEntity {
    @Attribute(.unique) var id: String
    var type: String
    var title: String
    var desc: String
    var lat: Double
    var lng: Double
    var geohash: String
    var photoUrls: String
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var status: String
    var voteUp: Int
    var voteDown: Int
    var regionCode: String
    var expiresAt: Date?
    var accessPublic: Bool
    var accessNotes: String
    var streetAddress: String
    var locality: String
    var administrativeArea: String
    var formattedAddress: String

    init(id: String,
         type: String,
         title: String,
         desc: String,
         lat: Double,
         lng: Double,
         geohash: String,
         photoUrls: String,
         createdBy: String,
         createdAt: Date,
         updatedAt: Date,
         status: String,
         voteUp: Int,
         voteDown: Int,
         regionCode: String,
         expiresAt: Date? = nil,
         accessPublic: Bool,
         accessNotes: String,
         streetAddress: String,
         locality: String,
         administrativeArea: String,
         formattedAddress: String) {
        self.id = id
        self.type = type
        self.title = title
        self.desc = desc
        self.lat = lat
        self.lng = lng
        self.geohash = geohash
        self.photoUrls = photoUrls
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.voteUp = voteUp
        self.voteDown = voteDown
        self.regionCode = regionCode
        self.expiresAt = expiresAt
        self.accessPublic = accessPublic
        self.accessNotes = accessNotes
        self.streetAddress = streetAddress
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.formattedAddress = formattedAddress
    }

    func toDomain() -> Poi {
        return Poi(
            id: id,
            type: type,
            title: title,
            desc: desc,
            lat: lat,
            lng: lng,
            geohash: geohash,
            photoUrls: photoUrls.split(separator: ",").map(String.init).filter { !$0.isEmpty },
            createdBy: createdBy,
            createdAt: nil,
            updatedAt: nil,
            status: status,
            voteUp: voteUp,
            voteDown: voteDown,
            regionCode: regionCode,
            expiresAt: nil,
            access: AccessInfo(public: accessPublic, notes: accessNotes),
            streetAddress: streetAddress,
            locality: locality,
            administrativeArea: administrativeArea,
            formattedAddress: formattedAddress
        )
    }

    static func fromDomain(_ poi: Poi) -> PoiEntity {
        return PoiEntity(
            id: poi.id ?? UUID().uuidString,
            type: poi.type,
            title: poi.title,
            desc: poi.desc,
            lat: poi.lat,
            lng: poi.lng,
            geohash: poi.geohash,
            photoUrls: poi.photoUrls.joined(separator: ","),
            createdBy: poi.createdBy,
            createdAt: poi.createdAt?.dateValue() ?? Date(),
            updatedAt: poi.updatedAt?.dateValue() ?? Date(),
            status: poi.status,
            voteUp: poi.voteUp,
            voteDown: poi.voteDown,
            regionCode: poi.regionCode,
            expiresAt: poi.expiresAt?.dateValue(),
            accessPublic: poi.access?.public ?? true,
            accessNotes: poi.access?.notes ?? "",
            streetAddress: poi.streetAddress,
            locality: poi.locality,
            administrativeArea: poi.administrativeArea,
            formattedAddress: poi.formattedAddress
        )
    }
}
#endif
