import SwiftUI
import MapKit

struct LivestockFieldOverlay: View {
    let fields: [LivestockField]
    let selectedFieldId: String?
    let onFieldTap: (LivestockField) -> Void

    var body: some View {
        ForEach(fields) { field in
            if !field.polygon.isEmpty {
                LivestockFieldPolygon(
                    field: field,
                    isSelected: field.fieldId == selectedFieldId,
                    onTap: { onFieldTap(field) }
                )
            }
        }
    }
}

struct LivestockFieldPolygon: View {
    let field: LivestockField
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        MapPolygon(coordinates: field.polygon)
            .foregroundStyle(fillColor.opacity(fillOpacity))
            .stroke(strokeColor, lineWidth: strokeWidth)
            .tag(field.fieldId)

        if let topSpecies = field.topSpecies, topSpecies != .other {
            ForEach(iconPositions, id: \.latitude) { position in
                Annotation("", coordinate: position) {
                    LivestockFieldIcon(
                        species: topSpecies,
                        isDangerous: field.isDangerous
                    )
                }
                .annotationTitles(.hidden)
            }
        }
    }

    private var colorScheme: FieldColorScheme {
        FieldColorScheme.forConfidence(field.confidenceLevel, isSelected: isSelected)
    }

    private var fillColor: Color {
        colorScheme.fill
    }

    private var strokeColor: Color {
        colorScheme.stroke
    }

    private var fillOpacity: Double {
        isSelected ? 0.6 : 0.35
    }

    private var strokeWidth: CGFloat {
        isSelected ? 4 : 2
    }

    private var iconPositions: [CLLocationCoordinate2D] {
        LivestockFieldHelper.calculateIconPositions(polygon: field.polygon, count: 3)
    }
}

struct LivestockFieldIcon: View {
    let species: LivestockSpecies
    let isDangerous: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 32, height: 32)

            if isDangerous {
                Circle()
                    .stroke(.red, lineWidth: 3)
                    .frame(width: 32, height: 32)
            }

            Image(systemName: species.iconName)
                .font(.system(size: 18))
                .foregroundStyle(isDangerous ? .red : .primary)
        }
    }
}

struct FieldColorScheme {
    let fill: Color
    let stroke: Color

    static func forConfidence(_ level: ConfidenceLevel, isSelected: Bool) -> FieldColorScheme {
        switch level {
        case .high:
            return FieldColorScheme(
                fill: Color(red: 0.30, green: 0.69, blue: 0.31),
                stroke: Color(red: 0.18, green: 0.49, blue: 0.20)
            )
        case .medium:
            return FieldColorScheme(
                fill: Color(red: 1.0, green: 0.76, blue: 0.03),
                stroke: Color(red: 0.96, green: 0.49, blue: 0.0)
            )
        case .low:
            return FieldColorScheme(
                fill: Color(red: 1.0, green: 0.60, blue: 0.0),
                stroke: Color(red: 0.90, green: 0.32, blue: 0.0)
            )
        case .noLivestock:
            return FieldColorScheme(
                fill: Color(red: 0.62, green: 0.62, blue: 0.62),
                stroke: Color(red: 0.38, green: 0.38, blue: 0.38)
            )
        case .unknown:
            return FieldColorScheme(
                fill: Color(red: 0.55, green: 0.27, blue: 0.07),
                stroke: Color(red: 0.40, green: 0.26, blue: 0.13)
            )
        }
    }
}

struct LivestockFieldHelper {
    static func calculateIconPositions(polygon: [CLLocationCoordinate2D], count: Int) -> [CLLocationCoordinate2D] {
        guard !polygon.isEmpty else { return [] }

        let minLat = polygon.map { $0.latitude }.min() ?? 0
        let maxLat = polygon.map { $0.latitude }.max() ?? 0
        let minLng = polygon.map { $0.longitude }.min() ?? 0
        let maxLng = polygon.map { $0.longitude }.max() ?? 0

        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2

        var positions: [CLLocationCoordinate2D] = []

        switch count {
        case 1:
            positions.append(CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng))
        case 2:
            let offset = (maxLat - minLat) * 0.25
            positions.append(CLLocationCoordinate2D(latitude: centerLat - offset, longitude: centerLng))
            positions.append(CLLocationCoordinate2D(latitude: centerLat + offset, longitude: centerLng))
        default:
            let latOffset = (maxLat - minLat) * 0.25
            let lngOffset = (maxLng - minLng) * 0.25
            positions.append(CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng - lngOffset))
            positions.append(CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng + lngOffset))
            positions.append(CLLocationCoordinate2D(latitude: centerLat + latOffset, longitude: centerLng))
        }

        return positions.filter { isPointInPolygon(point: $0, polygon: polygon) }
    }

    static func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        var intersections = 0
        let x = point.longitude
        let y = point.latitude

        for i in 0..<polygon.count {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % polygon.count]

            if (p1.latitude > y) != (p2.latitude > y) {
                let xIntersect = (p2.longitude - p1.longitude) * (y - p1.latitude) /
                                (p2.latitude - p1.latitude) + p1.longitude
                if x < xIntersect {
                    intersections += 1
                }
            }
        }

        return intersections % 2 == 1
    }
}
