import Foundation

class OsrmService {
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
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "overview", value: overview),
            URLQueryItem(name: "geometries", value: geometries),
            URLQueryItem(name: "steps", value: String(steps)),
            URLQueryItem(name: "alternatives", value: String(alternatives))
        ]
        if let continueStraight = continueStraight {
            queryItems.append(URLQueryItem(name: "continue_straight", value: String(continueStraight)))
        }
        if let bearings = bearings {
            queryItems.append(URLQueryItem(name: "bearings", value: bearings))
        }
        if let radiuses = radiuses {
            queryItems.append(URLQueryItem(name: "radiuses", value: radiuses))
        }

        let (data, _) = try await SmartOsrmEndpoint.loadData(
            path: "/route/v1/foot/\(coordinates)",
            coordinates: coordinates,
            queryItems: queryItems
        )
        return try JSONDecoder().decode(OsrmRouteResponse.self, from: data)
    }

    func getNearest(
        coordinates: String,
        number: Int = 1
    ) async throws -> OsrmNearestResponse {
        let (data, _) = try await SmartOsrmEndpoint.loadData(
            path: "/nearest/v1/foot/\(coordinates)",
            coordinates: coordinates,
            queryItems: [URLQueryItem(name: "number", value: String(number))]
        )
        return try JSONDecoder().decode(OsrmNearestResponse.self, from: data)
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
