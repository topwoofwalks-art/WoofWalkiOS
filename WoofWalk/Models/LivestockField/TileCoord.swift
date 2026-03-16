import Foundation
import CoreLocation
import MapKit

struct TileCoord: Codable, Equatable, Hashable {
    let z: Int
    let x: Int
    let y: Int

    init(z: Int, x: Int, y: Int) {
        self.z = z
        self.x = x
        self.y = y
    }

    static func from(coordinate: CLLocationCoordinate2D, zoom: Int) -> TileCoord {
        let n = 1 << zoom
        let lng = coordinate.longitude
        let lat = coordinate.latitude

        let xtile = Int((lng + 180.0) / 360.0 * Double(n))
        let latRad = lat * .pi / 180.0
        let ytile = Int((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * Double(n))

        return TileCoord(z: zoom, x: xtile, y: ytile)
    }

    var tileId: String {
        "\(z)/\(x)/\(y)"
    }
}
