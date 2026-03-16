import Foundation
import CoreLocation

struct Route: Codable, Identifiable {
    let id: UUID
    let summary: String
    let polyline: String
    let legs: [RouteLeg]
    let warnings: [String]
    let bounds: RouteBounds?

    init(
        id: UUID = UUID(),
        summary: String,
        polyline: String,
        legs: [RouteLeg],
        warnings: [String] = [],
        bounds: RouteBounds? = nil
    ) {
        self.id = id
        self.summary = summary
        self.polyline = polyline
        self.legs = legs
        self.warnings = warnings
        self.bounds = bounds
    }

    var totalDistance: Double {
        legs.reduce(0) { $0 + $1.distance }
    }

    var totalDuration: Double {
        legs.reduce(0) { $0 + $1.duration }
    }

    var allSteps: [RouteStep] {
        legs.flatMap { $0.steps }
    }

    var decodedPolyline: [CLLocationCoordinate2D] {
        NavigationLogic.decodePolyline(polyline)
    }

    var formattedDistance: String {
        if totalDistance < 1000 {
            return "\(Int(totalDistance)) m"
        } else {
            return String(format: "%.1f km", totalDistance / 1000)
        }
    }

    var formattedDuration: String {
        let seconds = Int(totalDuration)
        if seconds < 60 {
            return "< 1 min"
        } else if seconds < 3600 {
            return "\(seconds / 60) min"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours) hr \(mins) min" : "\(hours) hr"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case summary
        case polyline = "overview_polyline"
        case legs
        case warnings
        case bounds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        summary = try container.decode(String.self, forKey: .summary)

        if let polylineDict = try? container.decode([String: String].self, forKey: .polyline) {
            polyline = polylineDict["points"] ?? ""
        } else {
            polyline = ""
        }

        legs = try container.decode([RouteLeg].self, forKey: .legs)
        warnings = (try? container.decode([String].self, forKey: .warnings)) ?? []
        bounds = try? container.decode(RouteBounds.self, forKey: .bounds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(summary, forKey: .summary)
        try container.encode(["points": polyline], forKey: .polyline)
        try container.encode(legs, forKey: .legs)
        try container.encode(warnings, forKey: .warnings)
        try container.encodeIfPresent(bounds, forKey: .bounds)
    }
}

struct RouteLeg: Codable, Identifiable {
    let id: UUID
    let distance: Double
    let duration: Double
    let startLocation: CLLocationCoordinate2D
    let endLocation: CLLocationCoordinate2D
    let steps: [RouteStep]

    init(
        id: UUID = UUID(),
        distance: Double,
        duration: Double,
        startLocation: CLLocationCoordinate2D,
        endLocation: CLLocationCoordinate2D,
        steps: [RouteStep]
    ) {
        self.id = id
        self.distance = distance
        self.duration = duration
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.steps = steps
    }

    enum CodingKeys: String, CodingKey {
        case id
        case distance
        case duration
        case startLocation = "start_location"
        case endLocation = "end_location"
        case steps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()

        let distanceDict = try container.decode([String: CodableValue].self, forKey: .distance)
        distance = distanceDict["value"]?.doubleValue ?? 0.0

        let durationDict = try container.decode([String: CodableValue].self, forKey: .duration)
        duration = durationDict["value"]?.doubleValue ?? 0.0

        let startDict = try container.decode([String: Double].self, forKey: .startLocation)
        startLocation = CLLocationCoordinate2D(
            latitude: startDict["lat"] ?? 0.0,
            longitude: startDict["lng"] ?? 0.0
        )

        let endDict = try container.decode([String: Double].self, forKey: .endLocation)
        endLocation = CLLocationCoordinate2D(
            latitude: endDict["lat"] ?? 0.0,
            longitude: endDict["lng"] ?? 0.0
        )

        steps = try container.decode([RouteStep].self, forKey: .steps)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(["value": distance, "text": formatDistance(distance)], forKey: .distance)
        try container.encode(["value": duration, "text": formatDuration(duration)], forKey: .duration)
        try container.encode(["lat": startLocation.latitude, "lng": startLocation.longitude], forKey: .startLocation)
        try container.encode(["lat": endLocation.latitude, "lng": endLocation.longitude], forKey: .endLocation)
        try container.encode(steps, forKey: .steps)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let sec = Int(seconds)
        if sec < 60 {
            return "< 1 min"
        } else if sec < 3600 {
            return "\(sec / 60) min"
        } else {
            let hours = sec / 3600
            let mins = (sec % 3600) / 60
            return mins > 0 ? "\(hours) hr \(mins) min" : "\(hours) hr"
        }
    }
}

struct RouteBounds: Codable, Equatable {
    let northeast: CLLocationCoordinate2D
    let southwest: CLLocationCoordinate2D

    init(northeast: CLLocationCoordinate2D, southwest: CLLocationCoordinate2D) {
        self.northeast = northeast
        self.southwest = southwest
    }

    enum CodingKeys: String, CodingKey {
        case northeast
        case southwest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let neDict = try container.decode([String: Double].self, forKey: .northeast)
        northeast = CLLocationCoordinate2D(
            latitude: neDict["lat"] ?? 0.0,
            longitude: neDict["lng"] ?? 0.0
        )

        let swDict = try container.decode([String: Double].self, forKey: .southwest)
        southwest = CLLocationCoordinate2D(
            latitude: swDict["lat"] ?? 0.0,
            longitude: swDict["lng"] ?? 0.0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(["lat": northeast.latitude, "lng": northeast.longitude], forKey: .northeast)
        try container.encode(["lat": southwest.latitude, "lng": southwest.longitude], forKey: .southwest)
    }

    static func == (lhs: RouteBounds, rhs: RouteBounds) -> Bool {
        return lhs.northeast.latitude == rhs.northeast.latitude &&
               lhs.northeast.longitude == rhs.northeast.longitude &&
               lhs.southwest.latitude == rhs.southwest.latitude &&
               lhs.southwest.longitude == rhs.southwest.longitude
    }
}

extension CLLocationCoordinate2D: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: Double].self)
        self.init(
            latitude: dict["lat"] ?? 0.0,
            longitude: dict["lng"] ?? 0.0
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(["lat": latitude, "lng": longitude])
    }
}
