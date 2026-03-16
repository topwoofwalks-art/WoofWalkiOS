import Foundation
import CoreLocation

// MARK: - Walk Session Entity
struct WalkSessionEntity: Identifiable, Codable, Hashable {
    let id: String
    let sessionId: String
    let startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var durationSec: Int
    var avgPaceSecPerKm: Double?
    var notes: String?

    var isActive: Bool {
        endedAt == nil
    }

    var distanceKm: Double {
        distanceMeters / 1000.0
    }

    var durationFormatted: String {
        let hours = durationSec / 3600
        let minutes = (durationSec % 3600) / 60
        let seconds = durationSec % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
        }
    }

    var paceFormatted: String? {
        guard let pace = avgPaceSecPerKm else { return nil }
        let minutes = Int(pace / 60)
        let seconds = Int(pace.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var averageSpeed: Double? {
        guard durationSec > 0 else { return nil }
        return (distanceMeters / 1000.0) / (Double(durationSec) / 3600.0)
    }
}

// MARK: - Track Point Entity
struct TrackPointEntity: Identifiable, Codable, Hashable {
    let id: String
    let sessionId: String
    let lat: Double
    let lng: Double
    let accMeters: Float?
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var location: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: Double(accMeters ?? 0),
            verticalAccuracy: 0,
            timestamp: timestamp
        )
    }
}

// MARK: - Dog Walk Join
struct DogWalkJoin: Codable, Hashable {
    let dogId: String
    let sessionId: String
}

// MARK: - Walk Photo
struct WalkPhoto: Identifiable, Codable, Hashable {
    let id: String
    let sessionId: String
    let photoUrl: String
    let lat: Double?
    let lng: Double?
    let timestamp: Date
    let caption: String?
}

// MARK: - Waste Disposal Marker
struct WasteDisposalMarker: Identifiable, Codable, Hashable {
    let id: String
    let sessionId: String
    let lat: Double
    let lng: Double
    let timestamp: Date
    let type: WasteType

    enum WasteType: String, Codable {
        case poo
        case pee
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - Point of Interest
struct POIMarker: Identifiable, Codable, Hashable {
    let id: String
    let sessionId: String
    let name: String
    let lat: Double
    let lng: Double
    let timestamp: Date
    let category: POICategory

    enum POICategory: String, Codable, CaseIterable {
        case park = "Park"
        case waterStation = "Water Station"
        case dogPark = "Dog Park"
        case restArea = "Rest Area"
        case petStore = "Pet Store"
        case veterinary = "Veterinary"
        case other = "Other"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - Walk Statistics Summary
struct WalkStatisticsSummary: Codable {
    var totalWalks: Int = 0
    var totalDistanceMeters: Double = 0
    var totalDurationSec: Int = 0
    var longestWalkMeters: Double = 0
    var averageWalkMeters: Double = 0
    var averageDurationSec: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0

    var totalDistanceKm: Double {
        totalDistanceMeters / 1000.0
    }

    var averageDistanceKm: Double {
        averageWalkMeters / 1000.0
    }

    var longestWalkKm: Double {
        longestWalkMeters / 1000.0
    }

    var totalDurationFormatted: String {
        let hours = totalDurationSec / 3600
        let minutes = (totalDurationSec % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
}

// MARK: - Weekly Stats
struct WeeklyStats: Identifiable, Codable {
    var id: String { weekStart.ISO8601Format() }
    let weekStart: Date
    let weekEnd: Date
    var totalWalks: Int
    var totalDistanceMeters: Double
    var totalDurationSec: Int

    var distanceKm: Double {
        totalDistanceMeters / 1000.0
    }

    var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: weekStart)
    }
}

// MARK: - Monthly Stats
struct MonthlyStats: Identifiable, Codable {
    var id: String { monthStart.ISO8601Format() }
    let monthStart: Date
    let monthEnd: Date
    var totalWalks: Int
    var totalDistanceMeters: Double
    var totalDurationSec: Int

    var distanceKm: Double {
        totalDistanceMeters / 1000.0
    }

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: monthStart)
    }
}

// MARK: - Live Walk Metrics
struct LiveWalkMetrics {
    var currentSpeed: Double = 0.0 // km/h
    var averageSpeed: Double = 0.0 // km/h
    var currentPace: Double = 0.0 // min/km
    var averagePace: Double = 0.0 // min/km
    var distanceMeters: Double = 0.0
    var elapsedTime: TimeInterval = 0.0
    var estimatedTimeRemaining: TimeInterval? = nil
    var caloriesBurned: Int = 0
    var elevationGain: Double = 0.0
    var maxSpeed: Double = 0.0

    var distanceKm: Double {
        distanceMeters / 1000.0
    }

    var currentSpeedFormatted: String {
        String(format: "%.1f km/h", currentSpeed)
    }

    var averageSpeedFormatted: String {
        String(format: "%.1f km/h", averageSpeed)
    }

    var currentPaceFormatted: String {
        let minutes = Int(currentPace)
        let seconds = Int((currentPace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var averagePaceFormatted: String {
        let minutes = Int(averagePace)
        let seconds = Int((averagePace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var elapsedTimeFormatted: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Walk Validation Result
struct WalkValidationResult {
    var isValid: Bool
    var points: Int
    var basePoints: Int
    var bonusPoints: Int
    var penaltyPoints: Int
    var reason: String
    var violations: [String]
}

// MARK: - Route Segment (speed-categorized, for walk analysis)
struct WalkRouteSegment: Identifiable {
    let id: String
    let points: [TrackPointEntity]
    let distance: Double
    let duration: TimeInterval
    let averageSpeed: Double

    var speedCategory: SpeedCategory {
        if averageSpeed < 3.0 {
            return .slow
        } else if averageSpeed < 6.0 {
            return .moderate
        } else {
            return .fast
        }
    }

    enum SpeedCategory {
        case slow
        case moderate
        case fast
    }
}

// MARK: - Walk Goal
struct WalkGoal: Identifiable, Codable {
    let id: String
    var goalType: GoalType
    var targetValue: Double
    var currentValue: Double
    var startDate: Date
    var endDate: Date

    enum GoalType: String, Codable {
        case dailyDistance
        case weeklyDistance
        case monthlyDistance
        case dailyWalks
        case weeklyWalks
        case streak
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }

    var isCompleted: Bool {
        currentValue >= targetValue
    }

    var remainingValue: Double {
        max(targetValue - currentValue, 0)
    }
}
