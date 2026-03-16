import Foundation
import CoreLocation
@testable import WoofWalk

struct TestDataBuilder {
    static func createTestUser(
        id: String = "test-user-123",
        email: String = "test@example.com",
        displayName: String = "Test User"
    ) -> User {
        User(
            id: id,
            email: email,
            displayName: displayName,
            createdAt: Date()
        )
    }

    static func createTestWalk(
        id: String = "walk-123",
        userId: String = "test-user-123",
        distanceMeters: Int = 5000,
        durationSec: Int = 3600,
        syncedToFirestore: Bool = true
    ) -> WalkEntity {
        let walk = WalkEntity(
            id: id,
            userId: userId,
            startedAt: Date().addingTimeInterval(-3600),
            distanceMeters: distanceMeters,
            durationSec: durationSec
        )
        walk.syncedToFirestore = syncedToFirestore
        return walk
    }

    static func createTestPOI(
        id: String = "poi-123",
        type: POI.POIType = .bin,
        coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    ) -> POI {
        POI(
            id: id,
            title: "Test \(type.rawValue)",
            description: "Test POI",
            coordinate: coordinate,
            type: type,
            voteUp: 0,
            voteDown: 0,
            createdAt: Date()
        )
    }

    static func createTestLocation(
        latitude: Double = 51.5074,
        longitude: Double = -0.1278,
        accuracy: Double = 10.0
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy,
            timestamp: Date()
        )
    }

    static func createTestTrackPoints(count: Int = 10) -> [TrackPoint] {
        (0..<count).map { index in
            TrackPoint(
                t: Date().addingTimeInterval(Double(index * 10)).timeIntervalSince1970,
                lat: 51.5074 + Double(index) * 0.0001,
                lng: -0.1278 + Double(index) * 0.0001,
                acc: 10.0
            )
        }
    }

    static func createTestDog(
        id: String = "dog-123",
        name: String = "Buddy",
        breed: String = "Golden Retriever"
    ) -> DogProfile {
        DogProfile(
            id: id,
            name: name,
            breed: breed,
            birthdate: Date().addingTimeInterval(-31536000 * 3),
            weight: 30.0,
            notes: "Friendly dog"
        )
    }

    static func createTestWalkStats(
        totalWalks: Int = 5,
        totalDistanceMeters: Int = 25000,
        totalDurationSec: Int = 18000
    ) -> WalkStatsSummary {
        WalkStatsSummary(
            totalWalks: totalWalks,
            totalDistanceMeters: Double(totalDistanceMeters),
            totalTimeMinutes: totalDurationSec / 60,
            avgSpeedKmh: Double(totalDistanceMeters) / 1000.0 / (Double(totalDurationSec) / 3600.0)
        )
    }
}
