import Foundation
import CoreLocation

struct FieldGeometry: Codable {
    let type: String
    let coords: [[[Double]]]

    func toPolygon() -> [CLLocationCoordinate2D] {
        guard let ring = coords.first else { return [] }

        return ring.compactMap { coord in
            guard coord.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }
    }
}

struct FieldFeature: Codable {
    let fieldId: String
    let geom: FieldGeometry
    let bbox: [Double]
    let centroid: [Double]
    let area_m2: Double

    func toPolygon() -> [CLLocationCoordinate2D] {
        geom.toPolygon()
    }
}

struct FieldTile: Codable {
    let tileId: String
    let features: [FieldFeature]
    let checksum: String
    let version: String
    let cachedAt: TimeInterval

    init(
        tileId: String = "",
        features: [FieldFeature] = [],
        checksum: String = "",
        version: String = "1.0",
        cachedAt: TimeInterval = Date().timeIntervalSince1970 * 1000
    ) {
        self.tileId = tileId
        self.features = features
        self.checksum = checksum
        self.version = version
        self.cachedAt = cachedAt
    }
}
