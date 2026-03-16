import Foundation

class OsrmService {
    private let baseURL = "https://router.project-osrm.org/"
    private let networkManager = NetworkManager.shared

    func getRoute(
        coordinates: String,
        overview: String = "full",
        geometries: String = "polyline",
        steps: Bool = true,
        alternatives: Bool = true,
        continueStraight: Bool? = nil,
        bearings: String? = nil,
        radiuses: String? = nil
    ) async throws -> OsrmRouteResponse {
        guard let url = URL(string: "\(baseURL)route/v1/foot/\(coordinates)") else {
            throw NetworkError.invalidURL
        }

        var parameters: [String: Any] = [
            "overview": overview,
            "geometries": geometries,
            "steps": steps,
            "alternatives": alternatives
        ]

        if let continueStraight = continueStraight {
            parameters["continue_straight"] = continueStraight
        }
        if let bearings = bearings {
            parameters["bearings"] = bearings
        }
        if let radiuses = radiuses {
            parameters["radiuses"] = radiuses
        }

        return try await networkManager.request(
            url: url,
            parameters: parameters,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    func getNearest(
        coordinates: String,
        number: Int = 1
    ) async throws -> OsrmNearestResponse {
        guard let url = URL(string: "\(baseURL)nearest/v1/foot/\(coordinates)") else {
            throw NetworkError.invalidURL
        }

        let parameters: [String: Any] = [
            "number": number
        ]

        return try await networkManager.request(
            url: url,
            parameters: parameters,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    func getRoute(
        from: (latitude: Double, longitude: Double),
        to: (latitude: Double, longitude: Double),
        waypoints: [(latitude: Double, longitude: Double)]? = nil
    ) async throws -> OsrmRouteResponse {
        var coords = [from]
        if let waypoints = waypoints {
            coords.append(contentsOf: waypoints)
        }
        coords.append(to)

        let coordinatesString = coords
            .map { "\($0.longitude),\($0.latitude)" }
            .joined(separator: ";")

        return try await getRoute(coordinates: coordinatesString)
    }

    func getNearestRoad(
        latitude: Double,
        longitude: Double
    ) async throws -> OsrmNearestWaypoint? {
        let coordinates = "\(longitude),\(latitude)"
        let response = try await getNearest(coordinates: coordinates)
        return response.waypoints?.first
    }
}
