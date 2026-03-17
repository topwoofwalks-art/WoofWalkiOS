#if false
import SwiftData
import Foundation

@Model
final class TrackPointEntity {
    @Attribute(.unique) var id: String
    var sessionId: String
    var lat: Double
    var lng: Double
    var accMeters: Float?
    var timestamp: Date

    init(
        id: String,
        sessionId: String,
        lat: Double,
        lng: Double,
        accMeters: Float? = nil,
        timestamp: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.lat = lat
        self.lng = lng
        self.accMeters = accMeters
        self.timestamp = timestamp
    }
}

#endif
