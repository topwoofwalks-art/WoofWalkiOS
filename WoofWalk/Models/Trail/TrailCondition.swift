import Foundation
import SwiftUI
import CoreLocation
import FirebaseFirestore

// MARK: - Trail Condition Type

enum TrailConditionType: String, CaseIterable, Codable {
    case muddy, icy, flooded, overgrown, fallenTree, excellent, dry, wet, slippery

    var emoji: String {
        switch self {
        case .muddy: return "\u{1F4A9}"
        case .icy: return "\u{1F9CA}"
        case .flooded: return "\u{1F30A}"
        case .overgrown: return "\u{1F33F}"
        case .fallenTree: return "\u{1FAB5}"
        case .excellent: return "\u{2B50}"
        case .dry: return "\u{2600}\u{FE0F}"
        case .wet: return "\u{1F4A7}"
        case .slippery: return "\u{26A0}\u{FE0F}"
        }
    }

    var displayName: String {
        switch self {
        case .muddy: return "Muddy"
        case .icy: return "Icy"
        case .flooded: return "Flooded"
        case .overgrown: return "Overgrown"
        case .fallenTree: return "Fallen Tree"
        case .excellent: return "Excellent"
        case .dry: return "Dry"
        case .wet: return "Wet"
        case .slippery: return "Slippery"
        }
    }

    var expirationHours: Int {
        switch self {
        case .overgrown, .fallenTree: return 168 // 7 days
        default: return 48
        }
    }

    var color: Color {
        switch self {
        case .muddy: return Color.brown
        case .icy: return Color(red: 0.6, green: 0.85, blue: 1.0)
        case .flooded: return Color.blue
        case .overgrown: return Color.green
        case .fallenTree: return Color(red: 0.55, green: 0.35, blue: 0.17)
        case .excellent: return Color(red: 0.2, green: 0.8, blue: 0.2)
        case .dry: return Color.yellow
        case .wet: return Color(red: 0.3, green: 0.6, blue: 0.9)
        case .slippery: return Color.orange
        }
    }

    var iconName: String {
        switch self {
        case .muddy: return "drop.degreesign.fill"
        case .icy: return "snowflake"
        case .flooded: return "water.waves"
        case .overgrown: return "leaf.fill"
        case .fallenTree: return "tree.fill"
        case .excellent: return "star.fill"
        case .dry: return "sun.max.fill"
        case .wet: return "cloud.rain.fill"
        case .slippery: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Trail Condition

struct TrailCondition: Identifiable, Codable {
    @DocumentID var id: String?
    var type: String
    var severity: Int
    var note: String
    var lat: Double
    var lng: Double
    var reportedBy: String
    var voteUp: Int
    var voteDown: Int
    @ServerTimestamp var createdAt: Timestamp?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var conditionType: TrailConditionType {
        TrailConditionType(rawValue: type) ?? .wet
    }

    var isExpired: Bool {
        guard let created = createdAt?.dateValue() else { return false }
        let hours = conditionType.expirationHours
        let expirationDate = Calendar.current.date(byAdding: .hour, value: hours, to: created)!
        return Date() > expirationDate
    }

    var voteScore: Int {
        voteUp - voteDown
    }

    var severityLabel: String {
        switch severity {
        case 1: return "Minor"
        case 2: return "Moderate"
        case 3: return "Severe"
        default: return "Unknown"
        }
    }

    /// Distance in meters from a given coordinate
    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let from = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let to = CLLocation(latitude: lat, longitude: lng)
        return from.distance(from: to)
    }
}
