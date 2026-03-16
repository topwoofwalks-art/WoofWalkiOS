import Foundation
import CoreLocation

actor WalkingPathRepository {
    static let shared = WalkingPathRepository()

    private var cachedPaths: [String: WalkingPath] = [:]
    private let overpassService = OverpassService()
    private let cacheTimeout: TimeInterval = 1800

    private init() {}

    func fetchWalkingPaths(bounds: [CLLocationCoordinate2D]) async throws -> [WalkingPath] {
        guard bounds.count >= 2 else {
            print("[WALKING_PATHS] Insufficient bounds provided")
            return []
        }

        let south = bounds.map { $0.latitude }.min() ?? 0
        let west = bounds.map { $0.longitude }.min() ?? 0
        let north = bounds.map { $0.latitude }.max() ?? 0
        let east = bounds.map { $0.longitude }.max() ?? 0

        print("[WALKING_PATHS] Fetching paths in bounds: S=\(south), W=\(west), N=\(north), E=\(east)")

        let query = OverpassService.buildWalkingPathsQuery(
            south: south,
            west: west,
            north: north,
            east: east
        )

        let response = try await overpassService.query(query)

        let paths: [WalkingPath] = response.elements.compactMap { element in
            guard element.type == "way",
                  let geometry = element.geometry,
                  geometry.count >= 2 else {
                print("[WALKING_PATHS] Skipping element \(element.id) - invalid geometry")
                return nil
            }

            let coordinates = geometry.map {
                WalkingPath.Coordinate(latitude: $0.lat, longitude: $0.lon)
            }

            let highwayTag = element.tags?["highway"] ?? ""
            let pathType = WalkingPath.PathType.from(highwayTag: highwayTag)

            let length = calculatePathLength(coordinates)

            return WalkingPath(
                id: "osm_way_\(element.id)",
                pathType: pathType,
                coordinates: coordinates,
                name: element.tags?["name"],
                surface: element.tags?["surface"],
                length: length,
                accessRestrictions: element.tags?["access"],
                osmTags: element.tags ?? [:]
            )
        }

        for path in paths {
            cachedPaths[path.id] = path
        }

        print("[WALKING_PATHS] Fetched \(paths.count) paths, total cached: \(cachedPaths.count)")
        return paths
    }

    func getPathsInViewport(bounds: [CLLocationCoordinate2D]) async -> [WalkingPath] {
        guard bounds.count >= 2 else { return [] }

        let south = bounds.map { $0.latitude }.min() ?? 0
        let west = bounds.map { $0.longitude }.min() ?? 0
        let north = bounds.map { $0.latitude }.max() ?? 0
        let east = bounds.map { $0.longitude }.max() ?? 0

        return cachedPaths.values.filter { path in
            path.coordinates.contains { coord in
                coord.latitude >= south && coord.latitude <= north &&
                coord.longitude >= west && coord.longitude <= east
            }
        }
    }

    func getAllCachedPaths() async -> [WalkingPath] {
        Array(cachedPaths.values)
    }

    func findNearbyPaths(location: CLLocationCoordinate2D, radiusMeters: Double) async -> [WalkingPath] {
        cachedPaths.values.filter { path in
            path.coordinates.contains { coord in
                calculateDistance(
                    from: location,
                    to: coord.clLocationCoordinate2D
                ) <= radiusMeters
            }
        }.sorted { path1, path2 in
            let dist1 = path1.coordinates.map {
                calculateDistance(from: location, to: $0.clLocationCoordinate2D)
            }.min() ?? Double.infinity
            let dist2 = path2.coordinates.map {
                calculateDistance(from: location, to: $0.clLocationCoordinate2D)
            }.min() ?? Double.infinity
            return dist1 < dist2
        }
    }

    func findPathsForRouting(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        maxDetourMeters: Double = 500.0
    ) async -> [WalkingPath] {
        let directDistance = calculateDistance(from: start, to: end)
        let maxTotalDistance = directDistance + maxDetourMeters

        return cachedPaths.values.filter { path in
            let distanceToStart = path.coordinates.map {
                calculateDistance(from: start, to: $0.clLocationCoordinate2D)
            }.min() ?? Double.infinity

            let distanceToEnd = path.coordinates.map {
                calculateDistance(from: end, to: $0.clLocationCoordinate2D)
            }.min() ?? Double.infinity

            return distanceToStart <= 100.0 &&
                   distanceToEnd <= 100.0 &&
                   path.length <= maxTotalDistance
        }.sorted { $0.pathType.priority < $1.pathType.priority }
    }

    func clearCache() async {
        cachedPaths.removeAll()
        print("[WALKING_PATHS] Cache cleared")
    }

    private func calculatePathLength(_ coordinates: [WalkingPath.Coordinate]) -> Double {
        guard coordinates.count >= 2 else { return 0.0 }

        var totalLength = 0.0
        for i in 0..<(coordinates.count - 1) {
            totalLength += calculateDistance(
                from: coordinates[i].clLocationCoordinate2D,
                to: coordinates[i + 1].clLocationCoordinate2D
            )
        }
        return totalLength
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
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
