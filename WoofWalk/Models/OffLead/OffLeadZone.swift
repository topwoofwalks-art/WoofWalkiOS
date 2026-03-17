import Foundation
import SwiftUI
import CoreLocation
import MapKit

// MARK: - Zone Type

enum ZoneType: String, CaseIterable, Codable {
    case offLead, caution, leadRequired

    var color: Color {
        switch self {
        case .offLead: return .green
        case .caution: return .yellow
        case .leadRequired: return .red
        }
    }

    var displayName: String {
        switch self {
        case .offLead: return "Off-Lead"
        case .caution: return "Caution"
        case .leadRequired: return "Lead Required"
        }
    }

    var iconName: String {
        switch self {
        case .offLead: return "figure.walk.motion"
        case .caution: return "exclamationmark.triangle.fill"
        case .leadRequired: return "link"
        }
    }

    var emoji: String {
        switch self {
        case .offLead: return "\u{2705}"
        case .caution: return "\u{26A0}\u{FE0F}"
        case .leadRequired: return "\u{1F6AB}"
        }
    }

    var fillOpacity: Double {
        switch self {
        case .offLead: return 0.15
        case .caution: return 0.12
        case .leadRequired: return 0.18
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .offLead: return 0.6
        case .caution: return 0.5
        case .leadRequired: return 0.7
        }
    }
}

// MARK: - Off-Lead Zone

struct OffLeadZone: Identifiable, Codable {
    var id: String
    var name: String
    var type: String
    var coordinates: [[Double]] // array of [lat, lng] pairs

    var zoneType: ZoneType {
        ZoneType(rawValue: type) ?? .caution
    }

    /// Convert coordinate pairs to CLLocationCoordinate2D array
    var polygonCoordinates: [CLLocationCoordinate2D] {
        coordinates.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
    }

    /// Center point of the polygon (centroid)
    var center: CLLocationCoordinate2D {
        let coords = polygonCoordinates
        guard !coords.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        let totalLat = coords.reduce(0.0) { $0 + $1.latitude }
        let totalLng = coords.reduce(0.0) { $0 + $1.longitude }
        let count = Double(coords.count)
        return CLLocationCoordinate2D(latitude: totalLat / count, longitude: totalLng / count)
    }

    /// Check if a point is inside the polygon using ray casting
    func contains(_ point: CLLocationCoordinate2D) -> Bool {
        let coords = polygonCoordinates
        guard coords.count >= 3 else { return false }

        var inside = false
        var j = coords.count - 1

        for i in 0..<coords.count {
            let xi = coords[i].latitude
            let yi = coords[i].longitude
            let xj = coords[j].latitude
            let yj = coords[j].longitude

            let intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
                (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// MKPolygon for rendering on the map
    var mkPolygon: MKPolygon {
        var coords = polygonCoordinates
        return MKPolygon(coordinates: &coords, count: coords.count)
    }
}
