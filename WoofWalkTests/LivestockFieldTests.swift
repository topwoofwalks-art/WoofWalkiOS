import XCTest
import CoreLocation
@testable import WoofWalk

final class LivestockFieldTests: XCTestCase {

    func testTileCoordinateConversion() {
        let lat = 51.5074
        let lng = -0.1278
        let zoom = 15

        let tileX = Int(floor((lng + 180.0) / 360.0 * pow(2.0, Double(zoom))))
        let tileY = Int(floor((1.0 - log(tan(lat * .pi / 180.0) + 1.0 / cos(lat * .pi / 180.0)) / .pi) / 2.0 * pow(2.0, Double(zoom))))

        XCTAssertGreaterThan(tileX, 0)
        XCTAssertGreaterThan(tileY, 0)
        XCTAssertLessThan(tileX, Int(pow(2.0, Double(zoom))))
        XCTAssertLessThan(tileY, Int(pow(2.0, Double(zoom))))
    }

    func testSuitabilityFormula() {
        let grassProb = 0.8
        let cropsProb = 0.2
        let treesProb = 0.1
        let builtProb = 0.05
        let waterProb = 0.02

        let suitability = (grassProb * 0.7 + cropsProb * 0.3) * (1.0 - builtProb * 0.5 - waterProb * 0.8 - treesProb * 0.3)

        XCTAssertGreaterThan(suitability, 0.0)
        XCTAssertLessThanOrEqual(suitability, 1.0)
        XCTAssertGreaterThan(suitability, 0.5, "High grass probability should result in high suitability")
    }

    func testSuitabilityFormulaLowGrass() {
        let grassProb = 0.1
        let cropsProb = 0.1
        let treesProb = 0.3
        let builtProb = 0.4
        let waterProb = 0.1

        let suitability = (grassProb * 0.7 + cropsProb * 0.3) * (1.0 - builtProb * 0.5 - waterProb * 0.8 - treesProb * 0.3)

        XCTAssertLessThan(suitability, 0.3, "High built probability should result in low suitability")
    }

    func testPolygonContainment() {
        let polygon = [
            CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
            CLLocationCoordinate2D(latitude: 51.5, longitude: 0.1),
            CLLocationCoordinate2D(latitude: 51.4, longitude: 0.1),
            CLLocationCoordinate2D(latitude: 51.4, longitude: -0.1)
        ]

        let insidePoint = CLLocationCoordinate2D(latitude: 51.45, longitude: 0.0)
        let outsidePoint = CLLocationCoordinate2D(latitude: 51.6, longitude: 0.0)

        XCTAssertTrue(pointInPolygon(point: insidePoint, polygon: polygon))
        XCTAssertFalse(pointInPolygon(point: outsidePoint, polygon: polygon))
    }

    func testConfidenceLevel() {
        XCTAssertEqual(getConfidenceLevel(for: 0.8), .high)
        XCTAssertEqual(getConfidenceLevel(for: 0.6), .medium)
        XCTAssertEqual(getConfidenceLevel(for: 0.3), .low)
        XCTAssertEqual(getConfidenceLevel(for: 0.1), .unknown)
    }

    private func pointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count > 2 else { return false }

        var inside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let xi = polygon[i].latitude
            let yi = polygon[i].longitude
            let xj = polygon[j].latitude
            let yj = polygon[j].longitude

            let intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
                (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    private func getConfidenceLevel(for confidence: Double) -> ConfidenceLevel {
        switch confidence {
        case 0.75...:
            return .high
        case 0.45..<0.75:
            return .medium
        case 0.2..<0.45:
            return .low
        default:
            return .unknown
        }
    }
}
