import XCTest
import CoreLocation
@testable import WoofWalk

final class GeoHashUtilTests: XCTestCase {
    func testGeoHashGeneration() {
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

        let geohash = GeoHashUtil.encode(coordinate: coordinate, precision: 7)

        XCTAssertFalse(geohash.isEmpty)
        XCTAssertEqual(geohash.count, 7)
    }

    func testGeoHashDecoding() {
        let geohash = "gcpvj0d"

        let coordinate = GeoHashUtil.decode(geohash: geohash)

        XCTAssertNotNil(coordinate)
        XCTAssertEqual(coordinate?.latitude ?? 0, 51.5074, accuracy: 0.01)
        XCTAssertEqual(coordinate?.longitude ?? 0, -0.1278, accuracy: 0.01)
    }

    func testGeoHashNeighbors() {
        let geohash = "gcpvj0d"

        let neighbors = GeoHashUtil.neighbors(geohash: geohash)

        XCTAssertEqual(neighbors.count, 8)
        XCTAssertTrue(neighbors.contains { $0.hasPrefix("gcpvj") })
    }

    func testGeoHashPrecision() {
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

        let hash5 = GeoHashUtil.encode(coordinate: coordinate, precision: 5)
        let hash7 = GeoHashUtil.encode(coordinate: coordinate, precision: 7)

        XCTAssertEqual(hash5.count, 5)
        XCTAssertEqual(hash7.count, 7)
        XCTAssertTrue(hash7.hasPrefix(hash5))
    }

    func testGeoHashBoundingBox() {
        let geohash = "gcpvj"

        let bounds = GeoHashUtil.boundingBox(geohash: geohash)

        XCTAssertNotNil(bounds)
        XCTAssertLessThan(bounds!.minLat, bounds!.maxLat)
        XCTAssertLessThan(bounds!.minLng, bounds!.maxLng)
    }
}
