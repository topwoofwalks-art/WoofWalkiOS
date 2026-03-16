import Foundation
import CoreLocation

struct WalkingPath: Identifiable, Codable {
    let id: String
    let pathType: PathType
    let coordinates: [Coordinate]
    let name: String?
    let surface: String?
    let length: Double
    let accessRestrictions: String?
    let osmTags: [String: String]

    var pathId: String { id }

    enum PathType: String, Codable, CaseIterable {
        case footway
        case path
        case track
        case bridleway
        case cycleway
        case pedestrian
        case steps
        case unclassified
        case residential
        case service
        case livingStreet = "living_street"
        case tertiary
        case secondary
        case primary
        case unknown

        var displayName: String {
            switch self {
            case .footway: return "Footpath"
            case .path: return "Path"
            case .track: return "Track"
            case .bridleway: return "Bridleway"
            case .cycleway: return "Cycle Path"
            case .pedestrian: return "Pedestrian Zone"
            case .steps: return "Steps"
            case .unclassified: return "Minor Road"
            case .residential: return "Residential"
            case .service: return "Service Road"
            case .livingStreet: return "Living Street"
            case .tertiary: return "Tertiary Road"
            case .secondary: return "Secondary Road"
            case .primary: return "Primary Road"
            case .unknown: return "Unknown"
            }
        }

        var priority: Int {
            switch self {
            case .footway: return 1
            case .path: return 2
            case .bridleway: return 1
            case .track: return 3
            case .pedestrian: return 2
            case .cycleway: return 4
            case .steps: return 5
            case .livingStreet: return 6
            case .unclassified: return 6
            case .residential: return 7
            case .service: return 8
            case .tertiary: return 9
            case .secondary: return 10
            case .primary: return 11
            case .unknown: return 12
            }
        }

        static func from(highwayTag: String) -> PathType {
            switch highwayTag.lowercased() {
            case "footway": return .footway
            case "path": return .path
            case "track": return .track
            case "bridleway": return .bridleway
            case "cycleway": return .cycleway
            case "pedestrian": return .pedestrian
            case "steps": return .steps
            case "unclassified": return .unclassified
            case "residential": return .residential
            case "service": return .service
            case "living_street": return .livingStreet
            case "tertiary": return .tertiary
            case "secondary": return .secondary
            case "primary": return .primary
            default: return .unknown
            }
        }
    }

    struct Coordinate: Codable, Equatable {
        let latitude: Double
        let longitude: Double

        init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

        init(from location: CLLocationCoordinate2D) {
            self.latitude = location.latitude
            self.longitude = location.longitude
        }

        var clLocationCoordinate2D: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
}

extension WalkingPath {
    var qualityScore: Double {
        var score = Double(13 - pathType.priority)

        if let surface = surface?.lowercased() {
            if surface.contains("paved") || surface.contains("asphalt") || surface.contains("concrete") {
                score += 2.0
            } else if surface.contains("gravel") {
                score += 1.0
            }
        }

        if let width = osmTags["width"], let widthValue = Double(width) {
            if widthValue >= 3.0 {
                score += 1.5
            } else if widthValue >= 2.0 {
                score += 1.0
            }
        }

        if osmTags["wheelchair"] == "yes" || osmTags["stroller"] == "yes" {
            score += 1.0
        }

        return score
    }

    var isPedestrian: Bool {
        pathType.priority <= 5
    }
}
