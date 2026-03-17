#if false
import SwiftData
import Foundation

@Model
final class PooBagDropEntity {
    @Attribute(.unique) var id: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var notes: String?
    var isCollected: Bool
    var collectedAt: Date?

    init(
        id: String,
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        notes: String? = nil,
        isCollected: Bool = false,
        collectedAt: Date? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.notes = notes
        self.isCollected = isCollected
        self.collectedAt = collectedAt
    }
}

#endif
