#if false
import SwiftData
import Foundation

@Model
final class CachedPoiEntity {
    var id: Int64
    @Attribute(.unique) var osmId: String
    var name: String
    var type: String
    var latitude: Double
    var longitude: Double
    var tags: String
    var cachedAt: Date
    var regionLat: Double
    var regionLng: Double
    var radiusMeters: Double

    init(
        id: Int64 = 0,
        osmId: String,
        name: String,
        type: String,
        latitude: Double,
        longitude: Double,
        tags: String,
        cachedAt: Date = Date(),
        regionLat: Double,
        regionLng: Double,
        radiusMeters: Double
    ) {
        self.id = id
        self.osmId = osmId
        self.name = name
        self.type = type
        self.latitude = latitude
        self.longitude = longitude
        self.tags = tags
        self.cachedAt = cachedAt
        self.regionLat = regionLat
        self.regionLng = regionLng
        self.radiusMeters = radiusMeters
    }
}

#endif
