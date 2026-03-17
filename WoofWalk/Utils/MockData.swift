#if false
// MockData.swift - test data only, disabled to avoid build errors

import Foundation
import CoreLocation
import FirebaseFirestore

struct MockData {

    static func sampleLivestockFields() -> [LivestockField] {
        [
            LivestockField(
                fieldId: "field_001",
                centroid: GeoPoint(latitude: 51.5074, longitude: -0.1278),
                bbox: [-0.13, 51.50, -0.12, 51.51],
                area_m2: 15000,
                confidence: 0.85,
                speciesScores: ["CATTLE": 0.9, "SHEEP": 0.1],
                lastSeenAt: Date().timeIntervalSince1970 * 1000,
                lastNoLivestockAt: nil,
                votesUp: 15,
                votesDown: 2,
                signalCount: 17,
                decayedAt: nil,
                polygon: [
                    [-0.13, 51.50],
                    [-0.12, 51.50],
                    [-0.12, 51.51],
                    [-0.13, 51.51]
                ],
                isDangerous: false,
                isOsmField: true,
                osmLanduse: "farmland",
                dwGrassProbability: 0.8,
                dwCropsProbability: 0.15,
                dwTreesProbability: 0.03,
                dwBuiltProbability: 0.01,
                dwWaterProbability: 0.01,
                dwLastUpdated: Date().timeIntervalSince1970 * 1000
            ),
            LivestockField(
                fieldId: "field_002",
                centroid: GeoPoint(latitude: 51.5100, longitude: -0.1300),
                bbox: [-0.135, 51.505, -0.125, 51.515],
                area_m2: 22000,
                confidence: 0.72,
                speciesScores: ["SHEEP": 0.7, "CATTLE": 0.3],
                lastSeenAt: Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000,
                lastNoLivestockAt: nil,
                votesUp: 8,
                votesDown: 1,
                signalCount: 9,
                decayedAt: nil,
                polygon: [
                    [-0.135, 51.505],
                    [-0.125, 51.505],
                    [-0.125, 51.515],
                    [-0.135, 51.515]
                ],
                isDangerous: false,
                isOsmField: false,
                osmLanduse: nil,
                dwGrassProbability: 0.75,
                dwCropsProbability: 0.1,
                dwTreesProbabilities: 0.1,
                dwBuiltProbability: 0.02,
                dwWaterProbability: 0.03,
                dwLastUpdated: Date().addingTimeInterval(-172800).timeIntervalSince1970 * 1000
            ),
            LivestockField(
                fieldId: "field_003",
                centroid: GeoPoint(latitude: 51.5050, longitude: -0.1250),
                bbox: [-0.13, 51.50, -0.12, 51.51],
                area_m2: 18000,
                confidence: 0.45,
                speciesScores: ["HORSE": 0.6, "OTHER": 0.4],
                lastSeenAt: Date().addingTimeInterval(-259200).timeIntervalSince1970 * 1000,
                lastNoLivestockAt: nil,
                votesUp: 3,
                votesDown: 2,
                signalCount: 5,
                decayedAt: nil,
                polygon: [
                    [-0.13, 51.50],
                    [-0.12, 51.50],
                    [-0.12, 51.51],
                    [-0.13, 51.51]
                ],
                isDangerous: true,
                isOsmField: true,
                osmLanduse: "meadow",
                dwGrassProbability: 0.9,
                dwCropsProbability: 0.02,
                dwTreesProbability: 0.05,
                dwBuiltProbability: 0.01,
                dwWaterProbability: 0.02,
                dwLastUpdated: Date().addingTimeInterval(-604800).timeIntervalSince1970 * 1000
            )
        ]
    }

    static func sampleWalkingPaths() -> [WalkingPath] {
        [
            WalkingPath(
                id: "path_001",
                coordinates: [
                    Coordinate(lat: 51.5074, lng: -0.1278),
                    Coordinate(lat: 51.5080, lng: -0.1270),
                    Coordinate(lat: 51.5085, lng: -0.1265),
                    Coordinate(lat: 51.5090, lng: -0.1260)
                ],
                surfaceType: .paved,
                width: .wide,
                createdAt: Date().addingTimeInterval(-2592000),
                updatedAt: Date(),
                createdBy: "user_001",
                metadata: PathMetadata(
                    shadeLevel: .partial,
                    trafficLevel: .low,
                    difficulty: .easy,
                    accessibility: .full
                )
            ),
            WalkingPath(
                id: "path_002",
                coordinates: [
                    Coordinate(lat: 51.5100, lng: -0.1300),
                    Coordinate(lat: 51.5105, lng: -0.1290),
                    Coordinate(lat: 51.5110, lng: -0.1280),
                    Coordinate(lat: 51.5115, lng: -0.1270),
                    Coordinate(lat: 51.5120, lng: -0.1260)
                ],
                surfaceType: .gravel,
                width: .medium,
                createdAt: Date().addingTimeInterval(-1728000),
                updatedAt: Date(),
                createdBy: "user_002",
                metadata: PathMetadata(
                    shadeLevel: .full,
                    trafficLevel: .low,
                    difficulty: .easy,
                    accessibility: .full
                )
            ),
            WalkingPath(
                id: "path_003",
                coordinates: [
                    Coordinate(lat: 51.5050, lng: -0.1250),
                    Coordinate(lat: 51.5055, lng: -0.1245),
                    Coordinate(lat: 51.5060, lng: -0.1240)
                ],
                surfaceType: .grass,
                width: .narrow,
                createdAt: Date().addingTimeInterval(-864000),
                updatedAt: Date(),
                createdBy: "user_003",
                metadata: PathMetadata(
                    shadeLevel: .none,
                    trafficLevel: .medium,
                    difficulty: .moderate,
                    accessibility: .partial
                )
            ),
            WalkingPath(
                id: "path_004",
                coordinates: [
                    Coordinate(lat: 51.5120, lng: -0.1320),
                    Coordinate(lat: 51.5125, lng: -0.1315),
                    Coordinate(lat: 51.5130, lng: -0.1310),
                    Coordinate(lat: 51.5135, lng: -0.1305)
                ],
                surfaceType: .dirt,
                width: .medium,
                createdAt: Date().addingTimeInterval(-432000),
                updatedAt: Date(),
                createdBy: "user_004",
                metadata: PathMetadata(
                    shadeLevel: .partial,
                    trafficLevel: .high,
                    difficulty: .hard,
                    accessibility: .limited
                )
            )
        ]
    }

    static func sampleDynamicWorldData() -> [String: Double] {
        [
            "grass": 0.75,
            "crops": 0.15,
            "trees": 0.05,
            "built": 0.03,
            "water": 0.02
        ]
    }

    static func sampleTours() -> [GuidedTour] {
        [
            GuidedTour(
                id: "onboarding_tour",
                title: "Welcome to WoofWalk",
                description: "Learn the basics of using WoofWalk",
                steps: [
                    GuidedTourStep(
                        id: "step_1",
                        title: "Welcome",
                        message: "Welcome to WoofWalk! Let's get started with a quick tour.",
                        targetElement: nil,
                        action: nil,
                        order: 0,
                        isCompleted: false
                    ),
                    GuidedTourStep(
                        id: "step_2",
                        title: "Map Navigation",
                        message: "Use your fingers to pan and zoom the map.",
                        targetElement: "mapView",
                        action: .swipe,
                        order: 1,
                        isCompleted: false
                    ),
                    GuidedTourStep(
                        id: "step_3",
                        title: "Start Walking",
                        message: "Tap the start button to begin tracking your walk.",
                        targetElement: "startButton",
                        action: .tap,
                        order: 2,
                        isCompleted: false
                    )
                ],
                targetScreen: .map,
                priority: 1,
                completedAt: nil
            )
        ]
    }
}
#endif
