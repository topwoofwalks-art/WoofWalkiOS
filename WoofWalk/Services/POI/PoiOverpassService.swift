import Foundation
import CoreLocation

struct PoiOverpassElement: Codable {
    let type: String
    let id: Int64
    let lat: Double
    let lon: Double
    let tags: [String: String]?
}

struct PoiOverpassResponse: Codable {
    let elements: [PoiOverpassElement]
}

class PoiOverpassService {
    static let baseURL = "https://overpass-api.de/api/"

    static func buildDogFriendlyQuery(lat: Double, lng: Double, radiusMeters: Int = 1500) -> String {
        return """
        [out:json][timeout:25];
        (
          node(around:\(radiusMeters),\(lat),\(lng))["leisure"="dog_park"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="drinking_water"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="waste_basket"];
          node(around:\(radiusMeters),\(lat),\(lng))["leisure"="park"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="bench"];
          node(around:\(radiusMeters),\(lat),\(lng))["natural"="water"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="fountain"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="place_of_worship"];
          node(around:\(radiusMeters),\(lat),\(lng))["natural"="peak"];
          node(around:\(radiusMeters),\(lat),\(lng))["natural"="hill"];
          node(around:\(radiusMeters),\(lat),\(lng))["tourism"="viewpoint"];
          node(around:\(radiusMeters),\(lat),\(lng))["waterway"="waterfall"];
          node(around:\(radiusMeters),\(lat),\(lng))["natural"="waterfall"];
          node(around:\(radiusMeters),\(lat),\(lng))["tourism"="attraction"];
          node(around:\(radiusMeters),\(lat),\(lng))["tourism"="picnic_site"];
          node(around:\(radiusMeters),\(lat),\(lng))["leisure"="picnic_table"];
          way(around:\(radiusMeters),\(lat),\(lng))["waterway"="waterfall"];
          way(around:\(radiusMeters),\(lat),\(lng))["natural"="waterfall"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="pub"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="bar"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="cafe"]["dog"="yes"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="restaurant"]["dog"="yes"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="pub"]["dog"="yes"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="toilet"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="shelter"];
          node(around:\(radiusMeters),\(lat),\(lng))["amenity"="veterinary"];
        );
        out center body;
        """
    }

    func query(_ queryString: String) async throws -> PoiOverpassResponse {
        guard let url = URL(string: "\(Self.baseURL)interpreter") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(queryString)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(PoiOverpassResponse.self, from: data)
    }

    static func mapOsmTypeToPoiType(tags: [String: String]?) -> String {
        guard let tags = tags else { return PoiType.amenity.rawValue }

        if tags["leisure"] == "dog_park" { return PoiType.dogPark.rawValue }
        if tags["leisure"] == "park" { return PoiType.park.rawValue }
        if tags["amenity"] == "waste_basket" { return PoiType.bin.rawValue }
        if tags["amenity"] == "drinking_water" { return PoiType.water.rawValue }
        if tags["natural"] == "water" { return PoiType.water.rawValue }
        if tags["amenity"] == "fountain" { return PoiType.water.rawValue }
        if tags["amenity"] == "place_of_worship" { return PoiType.church.rawValue }
        if tags["natural"] == "peak" || tags["natural"] == "hill" { return PoiType.landscape.rawValue }
        if tags["tourism"] == "viewpoint" { return PoiType.landscape.rawValue }
        if tags["waterway"] == "waterfall" || tags["natural"] == "waterfall" { return PoiType.landscape.rawValue }
        if tags["amenity"] == "pub" || tags["amenity"] == "bar" { return PoiType.dogFriendlyPub.rawValue }
        if tags["amenity"] == "cafe" { return PoiType.dogFriendlyCafe.rawValue }
        if tags["amenity"] == "restaurant" { return PoiType.dogFriendlyRestaurant.rawValue }
        if tags["amenity"] == "toilet" || tags["amenity"] == "toilets" { return PoiType.toilet.rawValue }
        if tags["amenity"] == "shelter" { return PoiType.shelter.rawValue }
        if tags["amenity"] == "veterinary" { return PoiType.vet.rawValue }
        if tags["leisure"] == "picnic_table" { return PoiType.picnicTable.rawValue }
        if tags["tourism"] == "picnic_site" { return PoiType.picnicSite.rawValue }
        if tags["tourism"] == "attraction" { return PoiType.attraction.rawValue }

        return PoiType.amenity.rawValue
    }
}
