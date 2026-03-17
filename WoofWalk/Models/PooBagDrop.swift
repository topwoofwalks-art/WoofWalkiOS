#if false
// DISABLED: Duplicate SwiftData model - real PooBagDrop is defined elsewhere
import Foundation
import CoreLocation
import SwiftData

@Model
class PooBagDrop: Identifiable {
    @Attribute(.unique) var id: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var notes: String?
    var isCollected: Bool
    var collectedAt: Date?

    init(id: String = UUID().uuidString,
         latitude: Double,
         longitude: Double,
         timestamp: Date = Date(),
         notes: String? = nil,
         isCollected: Bool = false,
         collectedAt: Date? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.notes = notes
        self.isCollected = isCollected
        self.collectedAt = collectedAt
    }

    func toLatLng() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func getAgeMinutes() -> Int {
        return Int(Date().timeIntervalSince(timestamp) / 60)
    }
}
#endif
