#if false
import Foundation
import CoreLocation

extension WalkingPathRepository {
    func getPathSegmentsForRoute(waypoints: [CLLocationCoordinate2D]) async -> [PathSegment] {
        var segments: [PathSegment] = []

        guard waypoints.count >= 2 else { return segments }

        for i in 0..<(waypoints.count - 1) {
            let start = waypoints[i]
            let end = waypoints[i + 1]

            let paths = await findPathsForRouting(start: start, end: end)

            if let bestPath = paths.first {
                segments.append(PathSegment(
                    startPoint: start,
                    endPoint: end,
                    path: bestPath,
                    segmentIndex: i
                ))
            }
        }

        return segments
    }

    func suggestPedestrianAlternatives(
        route: [CLLocationCoordinate2D],
        preferPedestrian: Bool = true
    ) async -> RouteAlternative? {
        guard route.count >= 2 else { return nil }

        let nearbyPaths = await findNearbyPaths(
            location: route.first!,
            radiusMeters: 200.0
        )

        let pedestrianPaths = nearbyPaths.filter { $0.isPedestrian }

        guard !pedestrianPaths.isEmpty else { return nil }

        let totalPathQuality = pedestrianPaths.reduce(0.0) { $0 + $1.qualityScore }
        let avgQuality = totalPathQuality / Double(pedestrianPaths.count)

        if avgQuality > 5.0 {
            return RouteAlternative(
                reason: "Better pedestrian paths available",
                quality: avgQuality,
                paths: pedestrianPaths,
                estimatedDetourMeters: calculateAverageDetour(paths: pedestrianPaths, from: route.first!)
            )
        }

        return nil
    }

    private func calculateAverageDetour(paths: [WalkingPath], from point: CLLocationCoordinate2D) -> Double {
        let distances = paths.compactMap { path -> Double? in
            path.coordinates.map {
                calculateDistance(from: point, to: $0.clLocationCoordinate2D)
            }.min()
        }

        guard !distances.isEmpty else { return 0 }
        return distances.reduce(0.0, +) / Double(distances.count)
    }
}

struct PathSegment {
    let startPoint: CLLocationCoordinate2D
    let endPoint: CLLocationCoordinate2D
    let path: WalkingPath
    let segmentIndex: Int

    var isOptimal: Bool {
        path.pathType.priority <= 3
    }

    var description: String {
        if let name = path.name {
            return "Follow \(name) (\(path.pathType.displayName))"
        }
        return "Follow \(path.pathType.displayName)"
    }
}

struct RouteAlternative {
    let reason: String
    let quality: Double
    let paths: [WalkingPath]
    let estimatedDetourMeters: Double

    var isWorthwhile: Bool {
        quality > 5.0 && estimatedDetourMeters < 100.0
    }

    var description: String {
        let detour = estimatedDetourMeters > 0
            ? String(format: " (+%.0fm)", estimatedDetourMeters)
            : ""
        return "\(reason)\(detour) - Quality: \(String(format: "%.1f", quality))"
    }
}

extension WalkingPath {
    func intersects(with route: [CLLocationCoordinate2D], threshold: Double = 50.0) -> Bool {
        for routePoint in route {
            for pathCoord in coordinates {
                let distance = calculateHaversineDistance(
                    from: routePoint,
                    to: pathCoord.clLocationCoordinate2D
                )
                if distance <= threshold {
                    return true
                }
            }
        }
        return false
    }

    private func calculateHaversineDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let earthRadius = 6371000.0
        let dLat = (to.latitude - from.latitude) * .pi / 180.0
        let dLon = (to.longitude - from.longitude) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(from.latitude * .pi / 180.0) * cos(to.latitude * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
#endif
