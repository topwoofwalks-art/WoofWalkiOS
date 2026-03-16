import XCTest
import CoreLocation
@testable import WoofWalk

final class WalkingPathTests: XCTestCase {

    func testOffRouteDetection() {
        let path = [
            CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
            CLLocationCoordinate2D(latitude: 51.5, longitude: 0.0),
            CLLocationCoordinate2D(latitude: 51.5, longitude: 0.1)
        ]

        let onPath = CLLocationCoordinate2D(latitude: 51.5, longitude: 0.05)
        let offPath = CLLocationCoordinate2D(latitude: 51.6, longitude: 0.0)

        let distanceToOnPath = minDistanceToPath(point: onPath, path: path)
        let distanceToOffPath = minDistanceToPath(point: offPath, path: path)

        XCTAssertLessThan(distanceToOnPath, 100, "Point on path should be close")
        XCTAssertGreaterThan(distanceToOffPath, 10000, "Point off path should be far")
    }

    func testPathQualityScore() {
        let highQualityMetadata = PathMetadata(
            shadeLevel: .full,
            trafficLevel: .low,
            difficulty: .easy,
            accessibility: .full
        )

        let lowQualityMetadata = PathMetadata(
            shadeLevel: .none,
            trafficLevel: .high,
            difficulty: .hard,
            accessibility: .limited
        )

        let highScore = highQualityMetadata.qualityScore
        let lowScore = lowQualityMetadata.qualityScore

        XCTAssertGreaterThan(highScore, 0.8, "High quality path should have high score")
        XCTAssertLessThan(lowScore, 0.5, "Low quality path should have low score")
        XCTAssertGreaterThan(highScore, lowScore, "High quality should score higher than low quality")
    }

    func testSurfaceSuitability() {
        XCTAssertEqual(SurfaceType.paved.suitabilityScore, 1.0)
        XCTAssertGreaterThan(SurfaceType.gravel.suitabilityScore, SurfaceType.dirt.suitabilityScore)
        XCTAssertGreaterThan(SurfaceType.grass.suitabilityScore, SurfaceType.sand.suitabilityScore)
        XCTAssertLessThan(SurfaceType.sand.suitabilityScore, 0.5)
    }

    func testPathLengthCalculation() {
        let coordinates = [
            Coordinate(lat: 51.5, lng: -0.1),
            Coordinate(lat: 51.5, lng: 0.0),
            Coordinate(lat: 51.5, lng: 0.1)
        ]

        let length = calculatePathLength(coordinates: coordinates)

        XCTAssertGreaterThan(length, 0, "Path length should be positive")
        XCTAssertGreaterThan(length, 20000, "Path should be at least 20km based on coordinates")
    }

    func testClosestPointOnPath() {
        let coordinates = [
            Coordinate(lat: 51.5, lng: -0.1),
            Coordinate(lat: 51.5, lng: 0.0),
            Coordinate(lat: 51.5, lng: 0.1)
        ]

        let testPoint = CLLocationCoordinate2D(latitude: 51.51, longitude: 0.05)
        let closest = findClosestPoint(to: testPoint, in: coordinates)

        XCTAssertNotNil(closest)
        if let closest = closest {
            let distance = haversineDistance(
                from: testPoint,
                to: CLLocationCoordinate2D(latitude: closest.lat, longitude: closest.lng)
            )
            XCTAssertLessThan(distance, 5000, "Closest point should be reasonably close")
        }
    }

    private func minDistanceToPath(point: CLLocationCoordinate2D, path: [CLLocationCoordinate2D]) -> Double {
        var minDist = Double.infinity

        for coord in path {
            let dist = haversineDistance(from: point, to: coord)
            minDist = min(minDist, dist)
        }

        return minDist
    }

    private func calculatePathLength(coordinates: [Coordinate]) -> Double {
        guard coordinates.count >= 2 else { return 0.0 }

        var total = 0.0
        for i in 0..<coordinates.count - 1 {
            let c1 = coordinates[i]
            let c2 = coordinates[i + 1]
            let from = CLLocationCoordinate2D(latitude: c1.lat, longitude: c1.lng)
            let to = CLLocationCoordinate2D(latitude: c2.lat, longitude: c2.lng)
            total += haversineDistance(from: from, to: to)
        }
        return total
    }

    private func findClosestPoint(to point: CLLocationCoordinate2D, in coordinates: [Coordinate]) -> Coordinate? {
        var closest: Coordinate?
        var minDistance = Double.infinity

        for coord in coordinates {
            let coordPoint = CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)
            let distance = haversineDistance(from: point, to: coordPoint)

            if distance < minDistance {
                minDistance = distance
                closest = coord
            }
        }

        return closest
    }

    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let dLat = (to.latitude - from.latitude) * .pi / 180.0
        let dLng = (to.longitude - from.longitude) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(from.latitude * .pi / 180.0) * cos(to.latitude * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
