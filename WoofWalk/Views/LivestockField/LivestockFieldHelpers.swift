import Foundation
import CoreLocation
import MapKit

struct LivestockFieldCalculations {
    static func calculatePolygonArea(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 3 else { return 0 }

        var area: Double = 0
        let n = coordinates.count

        for i in 0..<n {
            let p1 = coordinates[i]
            let p2 = coordinates[(i + 1) % n]

            let lat1 = p1.latitude * .pi / 180
            let lat2 = p2.latitude * .pi / 180
            let lng1 = p1.longitude * .pi / 180
            let lng2 = p2.longitude * .pi / 180

            area += (lng2 - lng1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * 6378137 * 6378137 / 2)
        return area
    }

    static func calculateCentroid(_ coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }

        var totalLat: Double = 0
        var totalLng: Double = 0

        for coord in coordinates {
            totalLat += coord.latitude
            totalLng += coord.longitude
        }

        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coordinates.count),
            longitude: totalLng / Double(coordinates.count)
        )
    }

    static func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> [Double] {
        guard !coordinates.isEmpty else { return [] }

        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0

        return [minLng, minLat, maxLng, maxLat]
    }

    static func isValidPolygon(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        guard coordinates.count >= 3 else { return false }

        let area = calculatePolygonArea(coordinates)
        guard area > 0 else { return false }

        for coord in coordinates {
            if !CLLocationCoordinate2DIsValid(coord) {
                return false
            }
        }

        return true
    }

    static func simplifyPolygon(_ coordinates: [CLLocationCoordinate2D], tolerance: Double = 0.00001) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 3 else { return coordinates }

        var simplified: [CLLocationCoordinate2D] = [coordinates[0]]

        for i in 1..<(coordinates.count - 1) {
            let prev = simplified.last!
            let current = coordinates[i]
            let next = coordinates[i + 1]

            let distance = perpendicularDistance(point: current, lineStart: prev, lineEnd: next)

            if distance > tolerance {
                simplified.append(current)
            }
        }

        simplified.append(coordinates.last!)

        return simplified
    }

    private static func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        let mag = sqrt(dx * dx + dy * dy)
        if mag == 0 {
            let pdx = point.longitude - lineStart.longitude
            let pdy = point.latitude - lineStart.latitude
            return sqrt(pdx * pdx + pdy * pdy)
        }

        let u = ((point.longitude - lineStart.longitude) * dx +
                 (point.latitude - lineStart.latitude) * dy) / (mag * mag)

        let ix: Double
        let iy: Double

        if u < 0 {
            ix = lineStart.longitude
            iy = lineStart.latitude
        } else if u > 1 {
            ix = lineEnd.longitude
            iy = lineEnd.latitude
        } else {
            ix = lineStart.longitude + u * dx
            iy = lineStart.latitude + u * dy
        }

        let pdx = point.longitude - ix
        let pdy = point.latitude - iy

        return sqrt(pdx * pdx + pdy * pdy)
    }
}

struct LivestockFieldFormatter {
    static func formatArea(_ areaM2: Double, metric: Bool = true) -> String {
        if metric {
            if areaM2 >= 10000 {
                return String(format: "%.1f ha", areaM2 / 10000)
            } else {
                return String(format: "%.0f m²", areaM2)
            }
        } else {
            let acres = areaM2 / 4046.86
            if acres >= 1 {
                return String(format: "%.1f ac", acres)
            } else {
                let sqFt = areaM2 * 10.764
                return String(format: "%.0f ft²", sqFt)
            }
        }
    }

    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    static func formatConfidencePercentage(_ confidence: Double) -> String {
        String(format: "%.0f%%", confidence * 100)
    }

    static func formatTimestamp(_ timestamp: Int64) -> String {
        let now = Date().timeIntervalSince1970 * 1000
        let diff = now - Double(timestamp)
        let days = Int(diff / (24 * 60 * 60 * 1000))

        switch days {
        case 0:
            return "Today"
        case 1:
            return "Yesterday"
        case 2..<7:
            return "\(days) days ago"
        case 7..<30:
            let weeks = days / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        default:
            let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    static func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lngDirection = coordinate.longitude >= 0 ? "E" : "W"

        return String(
            format: "%.6f° %@, %.6f° %@",
            abs(coordinate.latitude), latDirection,
            abs(coordinate.longitude), lngDirection
        )
    }
}

struct LivestockFieldValidator {
    enum ValidationError: Error, LocalizedError {
        case tooFewVertices
        case invalidCoordinates
        case polygonTooSmall
        case polygonTooLarge
        case selfIntersecting

        var errorDescription: String? {
            switch self {
            case .tooFewVertices:
                return "A field must have at least 3 vertices"
            case .invalidCoordinates:
                return "One or more coordinates are invalid"
            case .polygonTooSmall:
                return "Field area is too small (minimum 100 m²)"
            case .polygonTooLarge:
                return "Field area is too large (maximum 1000 hectares)"
            case .selfIntersecting:
                return "Polygon edges cannot cross each other"
            }
        }
    }

    static func validate(_ coordinates: [CLLocationCoordinate2D]) throws {
        guard coordinates.count >= 3 else {
            throw ValidationError.tooFewVertices
        }

        for coord in coordinates {
            guard CLLocationCoordinate2DIsValid(coord) else {
                throw ValidationError.invalidCoordinates
            }
        }

        let area = LivestockFieldCalculations.calculatePolygonArea(coordinates)

        guard area >= 100 else {
            throw ValidationError.polygonTooSmall
        }

        guard area <= 10_000_000 else {
            throw ValidationError.polygonTooLarge
        }
    }

    static func validateSpeciesSelection(_ species: [LivestockSpecies]) -> Bool {
        !species.isEmpty
    }

    static func validateNotes(_ notes: String) -> Bool {
        notes.count <= 300
    }
}

// distance(to:) is defined in MapAnnotation.swift
