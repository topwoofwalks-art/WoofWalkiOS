import Foundation
import SwiftUI
import CoreLocation
import FirebaseFirestore

// MARK: - Hazard Type

enum HazardType: String, CaseIterable, Codable {
    case aggressiveDog = "AGGRESSIVE_DOG"
    case brokenGlass = "BROKEN_GLASS"
    case floodedPath = "FLOODED_PATH"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .aggressiveDog: return "Aggressive Dog"
        case .brokenGlass: return "Broken Glass"
        case .floodedPath: return "Flooded Path"
        case .other: return "Other Hazard"
        }
    }

    var emoji: String {
        switch self {
        case .aggressiveDog: return "\u{1F415}\u{200D}\u{1F9BA}"
        case .brokenGlass: return "\u{1F536}"
        case .floodedPath: return "\u{1F30A}"
        case .other: return "\u{26A0}\u{FE0F}"
        }
    }

    var expirationHours: Int {
        switch self {
        case .aggressiveDog: return 2
        case .brokenGlass: return 6
        case .floodedPath: return 12
        case .other: return 4
        }
    }

    var iconName: String {
        switch self {
        case .aggressiveDog: return "dog.fill"
        case .brokenGlass: return "exclamationmark.triangle.fill"
        case .floodedPath: return "water.waves"
        case .other: return "questionmark.diamond.fill"
        }
    }
}

// MARK: - Hazard Severity

enum HazardSeverity: String, CaseIterable, Codable {
    case critical, high, medium, low

    var alertDistanceMeters: Double {
        switch self {
        case .critical: return 1000
        case .high: return 500
        case .medium: return 300
        case .low: return 200
        }
    }

    var color: Color {
        switch self {
        case .critical: return Color(red: 0.8, green: 0, blue: 0)
        case .high: return Color.red
        case .medium: return Color.orange
        case .low: return Color(red: 1.0, green: 0.6, blue: 0.4)
        }
    }

    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

// MARK: - Hazard Report

struct HazardReport: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var type: String
    var severity: String
    var description: String
    var lat: Double
    var lng: Double
    var reportedBy: String
    @ServerTimestamp var createdAt: Timestamp?
    var expiresAt: Timestamp?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var hazardType: HazardType {
        HazardType(rawValue: type) ?? .other
    }

    var hazardSeverity: HazardSeverity {
        HazardSeverity(rawValue: severity) ?? .medium
    }

    var isExpired: Bool {
        guard let expires = expiresAt else { return false }
        return expires.dateValue() < Date()
    }

    /// Distance in meters from a given coordinate
    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let from = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let to = CLLocation(latitude: lat, longitude: lng)
        return from.distance(from: to)
    }

    /// Returns true if this hazard is within alert range of the given coordinate
    func isWithinAlertRange(of coordinate: CLLocationCoordinate2D) -> Bool {
        distance(from: coordinate) <= hazardSeverity.alertDistanceMeters
    }
}
