import Foundation
import FirebaseFirestore

struct PlannedWalk: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var title: String
    var description: String
    var startLocation: LatLngData
    var startLocationName: String
    var routePolyline: [LatLngData]
    var estimatedDistanceMeters: Double
    var estimatedDurationSec: Int64
    var plannedForDate: Int64?
    var notes: [String]
    var dogIds: [String]
    var poiIds: [String]
    var createdAt: Int64
    var updatedAt: Int64
    var completedWalkId: String?

    init(id: String? = nil, userId: String = "", title: String = "", description: String = "", startLocation: LatLngData = LatLngData(), startLocationName: String = "", routePolyline: [LatLngData] = [], estimatedDistanceMeters: Double = 0, estimatedDurationSec: Int64 = 0, plannedForDate: Int64? = nil, notes: [String] = [], dogIds: [String] = [], poiIds: [String] = [], createdAt: Int64 = 0, updatedAt: Int64 = 0, completedWalkId: String? = nil) {
        self.id = id; self.userId = userId; self.title = title; self.description = description; self.startLocation = startLocation; self.startLocationName = startLocationName; self.routePolyline = routePolyline; self.estimatedDistanceMeters = estimatedDistanceMeters; self.estimatedDurationSec = estimatedDurationSec; self.plannedForDate = plannedForDate; self.notes = notes; self.dogIds = dogIds; self.poiIds = poiIds; self.createdAt = createdAt; self.updatedAt = updatedAt; self.completedWalkId = completedWalkId
    }
}

struct LatLngData: Codable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double = 0, longitude: Double = 0) {
        self.latitude = latitude; self.longitude = longitude
    }
}

struct SharedRoute: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var title: String
    var description: String
    var routePoints: [LatLngData]
    var encodedPolyline: String
    var distance: Double
    var estimatedDuration: Int64
    var difficulty: String // "EASY", "MODERATE", "CHALLENGING"
    var tags: [String]
    var rating: Double
    var ratingCount: Int
    var timesImported: Int
    var latitude: Double
    var longitude: Double
    var geohash: String
    var createdAt: Int64
    var isPublic: Bool

    var shareCode: String { String((id ?? "").prefix(8)) }

    init(id: String? = nil, userId: String = "", userName: String = "", title: String = "", description: String = "", routePoints: [LatLngData] = [], encodedPolyline: String = "", distance: Double = 0, estimatedDuration: Int64 = 0, difficulty: String = "EASY", tags: [String] = [], rating: Double = 0, ratingCount: Int = 0, timesImported: Int = 0, latitude: Double = 0, longitude: Double = 0, geohash: String = "", createdAt: Int64 = 0, isPublic: Bool = true) {
        self.id = id; self.userId = userId; self.userName = userName; self.title = title; self.description = description; self.routePoints = routePoints; self.encodedPolyline = encodedPolyline; self.distance = distance; self.estimatedDuration = estimatedDuration; self.difficulty = difficulty; self.tags = tags; self.rating = rating; self.ratingCount = ratingCount; self.timesImported = timesImported; self.latitude = latitude; self.longitude = longitude; self.geohash = geohash; self.createdAt = createdAt; self.isPublic = isPublic
    }
}

struct LiveShareLink: Identifiable, Codable {
    var id: String
    var sessionId: String
    var userId: String
    var token: String
    var createdAt: Int64
    var expiresAt: Int64
    var isActive: Bool
    var walkerFirstName: String
    var dogNames: [String]
    var lastLat: Double
    var lastLng: Double
    var lastUpdatedAt: Int64
    var distanceMeters: Double
    var durationSec: Int64
    var routePoints: [[String: Double]]
    var walkEnded: Bool

    init(id: String = UUID().uuidString, sessionId: String = "", userId: String = "", token: String = UUID().uuidString, createdAt: Int64 = 0, expiresAt: Int64 = 0, isActive: Bool = true, walkerFirstName: String = "", dogNames: [String] = [], lastLat: Double = 0, lastLng: Double = 0, lastUpdatedAt: Int64 = 0, distanceMeters: Double = 0, durationSec: Int64 = 0, routePoints: [[String: Double]] = [], walkEnded: Bool = false) {
        self.id = id; self.sessionId = sessionId; self.userId = userId; self.token = token; self.createdAt = createdAt; self.expiresAt = expiresAt; self.isActive = isActive; self.walkerFirstName = walkerFirstName; self.dogNames = dogNames; self.lastLat = lastLat; self.lastLng = lastLng; self.lastUpdatedAt = lastUpdatedAt; self.distanceMeters = distanceMeters; self.durationSec = durationSec; self.routePoints = routePoints; self.walkEnded = walkEnded
    }
}
