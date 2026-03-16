import Foundation

struct OverpassResponse: Codable {
    let elements: [OverpassElement]
}

struct OverpassElement: Codable {
    let type: String
    let id: Int64
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
    let center: OverpassCenter?
    let geometry: [OverpassNode]?
    let bounds: OverpassBounds?
}

struct OverpassCenter: Codable {
    let lat: Double
    let lon: Double
}

struct OverpassNode: Codable {
    let lat: Double
    let lon: Double
}

struct OverpassBounds: Codable {
    let minlat: Double
    let minlon: Double
    let maxlat: Double
    let maxlon: Double
}
