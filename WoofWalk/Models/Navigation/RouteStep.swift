import Foundation
import CoreLocation

struct RouteStep: Codable, Identifiable {
    let id: UUID
    let instruction: String
    let distance: Double
    let duration: Double
    let startLocation: CLLocationCoordinate2D
    let endLocation: CLLocationCoordinate2D
    let maneuver: String?
    let polyline: String

    init(
        id: UUID = UUID(),
        instruction: String,
        distance: Double,
        duration: Double,
        startLocation: CLLocationCoordinate2D,
        endLocation: CLLocationCoordinate2D,
        maneuver: String? = nil,
        polyline: String = ""
    ) {
        self.id = id
        self.instruction = instruction
        self.distance = distance
        self.duration = duration
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.maneuver = maneuver
        self.polyline = polyline
    }

    enum CodingKeys: String, CodingKey {
        case id
        case instruction = "html_instructions"
        case distance
        case duration
        case startLocation = "start_location"
        case endLocation = "end_location"
        case maneuver
        case polyline
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        instruction = try container.decode(String.self, forKey: .instruction)

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

        maneuver = try? container.decode(String.self, forKey: .maneuver)

        if let polylineDict = try? container.decode([String: String].self, forKey: .polyline) {
            polyline = polylineDict["points"] ?? ""
        } else {
            polyline = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(instruction, forKey: .instruction)
        try container.encode(["value": distance, "text": formatDistance(distance)], forKey: .distance)
        try container.encode(["value": duration, "text": formatDuration(duration)], forKey: .duration)
        try container.encode(["lat": startLocation.latitude, "lng": startLocation.longitude], forKey: .startLocation)
        try container.encode(["lat": endLocation.latitude, "lng": endLocation.longitude], forKey: .endLocation)
        try container.encodeIfPresent(maneuver, forKey: .maneuver)
        try container.encode(["points": polyline], forKey: .polyline)
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

enum CodableValue: Codable {
    case int(Int)
    case double(Double)
    case string(String)

    var doubleValue: Double {
        switch self {
        case .int(let value): return Double(value)
        case .double(let value): return value
        case .string(let value): return Double(value) ?? 0.0
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode CodableValue"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }
}
