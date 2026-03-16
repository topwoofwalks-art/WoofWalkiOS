import Foundation
import CoreLocation
import FirebaseFirestore

struct FieldSignal: Codable, Identifiable {
    var id: String { fieldId + "_" + String(createdAt) }

    let fieldId: String
    let userId: String
    let species: [LivestockSpecies]
    let present: Bool
    let notes: String?
    let photoUrl: String?
    let location: GeoPoint
    let viewport: TileCoord
    let createdAt: TimeInterval
    let clientOs: String
    let appVersion: String
    var synced: Bool

    init(
        fieldId: String = "",
        userId: String = "",
        species: [LivestockSpecies] = [],
        present: Bool = true,
        notes: String? = nil,
        photoUrl: String? = nil,
        location: GeoPoint = GeoPoint(latitude: 0, longitude: 0),
        viewport: TileCoord = TileCoord(z: 0, x: 0, y: 0),
        createdAt: TimeInterval = Date().timeIntervalSince1970 * 1000,
        clientOs: String = "iOS",
        appVersion: String = "",
        synced: Bool = false
    ) {
        self.fieldId = fieldId
        self.userId = userId
        self.species = species
        self.present = present
        self.notes = notes
        self.photoUrl = photoUrl
        self.location = location
        self.viewport = viewport
        self.createdAt = createdAt
        self.clientOs = clientOs
        self.appVersion = appVersion
        self.synced = synced
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude
        )
    }
}
