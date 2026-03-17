#if false
import SwiftUI
import MapKit

struct RouteOverlay: View {
    let coordinates: [CLLocationCoordinate2D]
    let routeType: RouteType
    let showPawMarkers: Bool

    enum RouteType {
        case active
        case planned
        case guidance
        case offRoute

        var color: Color {
            switch self {
            case .active:
                return .blue
            case .planned:
                return .purple
            case .guidance:
                return .green
            case .offRoute:
                return .red
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .active:
                return 5
            case .planned:
                return 4
            case .guidance:
                return 6
            case .offRoute:
                return 6
            }
        }

        var lineDash: [CGFloat]? {
            switch self {
            case .planned:
                return [10, 5]
            default:
                return nil
            }
        }
    }

    var body: some View {
        ZStack {
            MapPolyline(coordinates: coordinates)
                .stroke(routeType.color, lineWidth: routeType.lineWidth)

            if showPawMarkers {
                ForEach(pawMarkerPositions, id: \.latitude) { coordinate in
                    Annotation("", coordinate: coordinate) {
                        PawMarker()
                    }
                }
            }
        }
    }

    private var pawMarkerPositions: [CLLocationCoordinate2D] {
        guard coordinates.count > 1 else { return [] }

        var markers: [CLLocationCoordinate2D] = []
        var accumulatedDistance: CLLocationDistance = 0
        let markerInterval: CLLocationDistance = 50

        for i in 1..<coordinates.count {
            let segment = CLLocation(
                latitude: coordinates[i-1].latitude,
                longitude: coordinates[i-1].longitude
            ).distance(
                from: CLLocation(
                    latitude: coordinates[i].latitude,
                    longitude: coordinates[i].longitude
                )
            )

            accumulatedDistance += segment

            if accumulatedDistance >= markerInterval {
                markers.append(coordinates[i])
                accumulatedDistance = 0
            }
        }

        return markers
    }
}

struct PawMarker: View {
    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(4)
            .background(Circle().fill(.blue.opacity(0.7)))
    }
}

struct DottedPolyline: View {
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        MapPolyline(coordinates: coordinates)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    dash: [10, 5]
                )
            )
    }
}

struct RouteStepSegment: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let instruction: String
    let distance: String
    let duration: String
    let isFootpath: Bool
}

struct MultiStepRoute: View {
    let segments: [RouteStepSegment]
    let showInstructions: Bool

    var body: some View {
        ForEach(segments) { segment in
            if segment.isFootpath {
                DottedPolyline(
                    coordinates: segment.coordinates,
                    color: .green,
                    lineWidth: 5
                )
            } else {
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(.purple, lineWidth: 5)
            }

            if showInstructions, let firstCoord = segment.coordinates.first {
                Annotation(segment.instruction, coordinate: firstCoord) {
                    RouteInstructionMarker(instruction: segment.instruction)
                }
            }
        }
    }
}

struct RouteInstructionMarker: View {
    let instruction: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .padding(8)
                .background(Circle().fill(.blue))
                .shadow(radius: 3)

            Text(cleanInstruction)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .shadow(radius: 2)
                )
                .lineLimit(2)
        }
    }

    private var iconName: String {
        if instruction.contains("left") {
            return "arrow.turn.up.left"
        } else if instruction.contains("right") {
            return "arrow.turn.up.right"
        } else if instruction.contains("straight") || instruction.contains("continue") {
            return "arrow.up"
        } else {
            return "arrow.right"
        }
    }

    private var cleanInstruction: String {
        instruction
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WalkRouteData {
    let id: String
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Int
    let walkTimeMinutes: Int
    let isPublic: Bool

    var distanceKm: Double {
        Double(distanceMeters) / 1000.0
    }

    var formattedDistance: String {
        if distanceMeters < 1000 {
            return "\(distanceMeters)m"
        } else {
            return String(format: "%.1fkm", distanceKm)
        }
    }

    var formattedTime: String {
        if walkTimeMinutes < 60 {
            return "\(walkTimeMinutes)min"
        } else {
            let hours = walkTimeMinutes / 60
            let mins = walkTimeMinutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

struct RoutePreviewCard: View {
    let route: WalkRouteData
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label(route.formattedDistance, systemImage: "figure.walk")
                        Label(route.formattedTime, systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Walk")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 8)
        )
    }
}

struct CircularRouteGenerator {
    static func generateWaypoints(
        from origin: CLLocationCoordinate2D,
        via viaPoint: CLLocationCoordinate2D,
        desiredDistance: CLLocationDistance
    ) -> [CLLocationCoordinate2D] {
        var waypoints: [CLLocationCoordinate2D] = [origin]

        let distanceToVia = origin.distance(to: viaPoint)
        let remainingDistance = desiredDistance - (distanceToVia * 2)

        if remainingDistance > 100 {
            let numWaypoints = Int(remainingDistance / 200)

            for i in 0..<numWaypoints {
                let angle = Double(i) * (360.0 / Double(numWaypoints))
                let radius = remainingDistance / Double(numWaypoints * 2)
                let waypoint = viaPoint.coordinateAtDistance(radius, bearing: angle)
                waypoints.append(waypoint)
            }
        }

        waypoints.append(origin)
        return waypoints
    }
}

extension CLLocationCoordinate2D {
    func coordinateAtDistance(_ distance: CLLocationDistance, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius: CLLocationDistance = 6371000
        let bearingRad = bearing * .pi / 180
        let latRad = latitude * .pi / 180
        let lonRad = longitude * .pi / 180

        let newLatRad = asin(
            sin(latRad) * cos(distance / earthRadius) +
            cos(latRad) * sin(distance / earthRadius) * cos(bearingRad)
        )

        let newLonRad = lonRad + atan2(
            sin(bearingRad) * sin(distance / earthRadius) * cos(latRad),
            cos(distance / earthRadius) - sin(latRad) * sin(newLatRad)
        )

        return CLLocationCoordinate2D(
            latitude: newLatRad * 180 / .pi,
            longitude: newLonRad * 180 / .pi
        )
    }
}

#endif
