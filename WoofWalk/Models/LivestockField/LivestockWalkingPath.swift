import Foundation
import CoreLocation

/// Coordinate type used by LivestockWalkingPath (distinct from WalkingPath.Coordinate)
struct Coordinate: Codable, Equatable {
    let lat: Double
    let lng: Double
}

struct LivestockWalkingPath: Identifiable, Codable, Equatable {
    let id: String
    let coordinates: [Coordinate]
    let surfaceType: SurfaceType
    let width: PathWidth
    let createdAt: Date
    let updatedAt: Date
    let createdBy: String
    var metadata: PathMetadata

    var polyline: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    var lengthMeters: Double {
        guard coordinates.count >= 2 else { return 0.0 }

        var total = 0.0
        for i in 0..<coordinates.count - 1 {
            let c1 = coordinates[i]
            let c2 = coordinates[i + 1]
            total += haversineDistance(
                lat1: c1.lat, lng1: c1.lng,
                lat2: c2.lat, lng2: c2.lng
            )
        }
        return total
    }

    func closestPoint(to coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }

        var closest: CLLocationCoordinate2D?
        var minDistance = Double.infinity

        for coord in coordinates {
            let point = CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)
            let distance = haversineDistance(
                lat1: coordinate.latitude, lng1: coordinate.longitude,
                lat2: point.latitude, lng2: point.longitude
            )

            if distance < minDistance {
                minDistance = distance
                closest = point
            }
        }

        return closest
    }

    private func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLng = (lng2 - lng1) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

enum SurfaceType: String, Codable, CaseIterable {
    case paved = "paved"
    case gravel = "gravel"
    case dirt = "dirt"
    case grass = "grass"
    case sand = "sand"
    case mixed = "mixed"

    var suitabilityScore: Double {
        switch self {
        case .paved: return 1.0
        case .gravel: return 0.8
        case .grass: return 0.7
        case .dirt: return 0.6
        case .sand: return 0.4
        case .mixed: return 0.5
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

enum PathWidth: String, Codable, CaseIterable {
    case narrow = "narrow"
    case medium = "medium"
    case wide = "wide"

    var displayName: String {
        rawValue.capitalized
    }

    var minWidthMeters: Double {
        switch self {
        case .narrow: return 1.0
        case .medium: return 2.0
        case .wide: return 3.0
        }
    }
}

struct PathMetadata: Codable, Equatable {
    var shadeLevel: ShadeLevel
    var trafficLevel: TrafficLevel
    var difficulty: Difficulty
    var accessibility: Accessibility

    var qualityScore: Double {
        (shadeLevel.score + trafficLevel.score + difficulty.score + accessibility.score) / 4.0
    }
}

enum ShadeLevel: String, Codable, CaseIterable {
    case none = "none"
    case partial = "partial"
    case full = "full"

    var score: Double {
        switch self {
        case .none: return 0.5
        case .partial: return 0.75
        case .full: return 1.0
        }
    }
}

enum TrafficLevel: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var score: Double {
        switch self {
        case .low: return 1.0
        case .medium: return 0.7
        case .high: return 0.4
        }
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case moderate = "moderate"
    case hard = "hard"

    var score: Double {
        switch self {
        case .easy: return 1.0
        case .moderate: return 0.7
        case .hard: return 0.4
        }
    }
}

enum Accessibility: String, Codable, CaseIterable {
    case full = "full"
    case partial = "partial"
    case limited = "limited"

    var score: Double {
        switch self {
        case .full: return 1.0
        case .partial: return 0.6
        case .limited: return 0.3
        }
    }
}
