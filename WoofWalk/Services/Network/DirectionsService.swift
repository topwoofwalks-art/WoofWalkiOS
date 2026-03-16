import Foundation

class DirectionsService {
    private let baseURL = "https://maps.googleapis.com/maps/api/"
    private let networkManager = NetworkManager.shared
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func getDirections(
        origin: String,
        destination: String,
        mode: String = "walking",
        alternatives: Bool = true,
        avoid: String? = nil,
        waypoints: String? = nil
    ) async throws -> DirectionsResponse {
        guard let url = URL(string: "\(baseURL)directions/json") else {
            throw NetworkError.invalidURL
        }

        var parameters: [String: Any] = [
            "origin": origin,
            "destination": destination,
            "mode": mode,
            "alternatives": alternatives,
            "key": apiKey
        ]

        if let avoid = avoid {
            parameters["avoid"] = avoid
        }
        if let waypoints = waypoints {
            parameters["waypoints"] = waypoints
        }

        return try await networkManager.request(
            url: url,
            parameters: parameters,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    func getDirections(
        from: (latitude: Double, longitude: Double),
        to: (latitude: Double, longitude: Double),
        mode: String = "walking",
        alternatives: Bool = true,
        avoid: String? = nil,
        waypoints: [(latitude: Double, longitude: Double)]? = nil
    ) async throws -> DirectionsResponse {
        let origin = "\(from.latitude),\(from.longitude)"
        let destination = "\(to.latitude),\(to.longitude)"

        let waypointsString = waypoints?.map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")

        return try await getDirections(
            origin: origin,
            destination: destination,
            mode: mode,
            alternatives: alternatives,
            avoid: avoid,
            waypoints: waypointsString
        )
    }
}
