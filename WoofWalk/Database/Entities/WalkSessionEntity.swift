#if false
import SwiftData
import Foundation

@Model
final class WalkSessionEntity {
    @Attribute(.unique) var sessionId: String
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var durationSec: Int64
    var avgPaceSecPerKm: Double?
    var notes: String?

    init(
        sessionId: String,
        startedAt: Date,
        endedAt: Date? = nil,
        distanceMeters: Double,
        durationSec: Int64,
        avgPaceSecPerKm: Double? = nil,
        notes: String? = nil
    ) {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.durationSec = durationSec
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.notes = notes
    }
}

#endif
