import Foundation
import FirebaseFirestore

struct WalkHistory: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    @ServerTimestamp var startedAt: Timestamp?
    @ServerTimestamp var endedAt: Timestamp?
    var distanceMeters: Int
    var durationSec: Int
    var track: [TrackPoint]
    var polyline: String
    var dogIds: [String]

    init(id: String? = nil,
         userId: String = "",
         startedAt: Timestamp? = nil,
         endedAt: Timestamp? = nil,
         distanceMeters: Int = 0,
         durationSec: Int = 0,
         track: [TrackPoint] = [],
         polyline: String = "",
         dogIds: [String] = []) {
        self.id = id
        self.userId = userId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.durationSec = durationSec
        self.track = track
        self.polyline = polyline
        self.dogIds = dogIds
    }
}

struct TrackPoint: Codable {
    var t: Int64
    var lat: Double
    var lng: Double
    var acc: Double

    init(t: Int64 = 0, lat: Double = 0.0, lng: Double = 0.0, acc: Double = 0.0) {
        self.t = t
        self.lat = lat
        self.lng = lng
        self.acc = acc
    }
}

struct WalkRoute: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var summary: String
    var polyline: String
    var distanceMeters: Int
    var elevGainM: Int
    var createdBy: String
    var `public`: Bool
    var ratingAvg: Double
    var ratingCount: Int
    var walkTimeMin: Int
    var tags: [String]
    var segments: [RouteSegment]
    @ServerTimestamp var updatedAt: Timestamp?

    init(id: String? = nil,
         name: String = "",
         summary: String = "",
         polyline: String = "",
         distanceMeters: Int = 0,
         elevGainM: Int = 0,
         createdBy: String = "",
         public: Bool = false,
         ratingAvg: Double = 0.0,
         ratingCount: Int = 0,
         walkTimeMin: Int = 0,
         tags: [String] = [],
         segments: [RouteSegment] = [],
         updatedAt: Timestamp? = nil) {
        self.id = id
        self.name = name
        self.summary = summary
        self.polyline = polyline
        self.distanceMeters = distanceMeters
        self.elevGainM = elevGainM
        self.createdBy = createdBy
        self.public = `public`
        self.ratingAvg = ratingAvg
        self.ratingCount = ratingCount
        self.walkTimeMin = walkTimeMin
        self.tags = tags
        self.segments = segments
        self.updatedAt = updatedAt
    }
}

struct RouteSegment: Codable {
    var lat: Double
    var lng: Double
    var geohash: String

    init(lat: Double = 0.0, lng: Double = 0.0, geohash: String = "") {
        self.lat = lat
        self.lng = lng
        self.geohash = geohash
    }
}
