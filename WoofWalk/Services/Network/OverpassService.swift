import Foundation

class OverpassService {
    static let baseURL = "https://overpass-api.de/api/"
    private let networkManager = NetworkManager.shared

    func query(_ query: String) async throws -> OverpassResponse {
        guard let url = URL(string: "\(Self.baseURL)interpreter") else {
            throw NetworkError.invalidURL
        }

        let parameters: [String: Any] = [
            "data": query
        ]

        return try await networkManager.request(
            url: url,
            parameters: parameters,
            cachePolicy: .reloadIgnoringLocalCacheData,
            retryCount: 3
        )
    }

    static func buildDogFriendlyQuery(
        latitude: Double,
        longitude: Double,
        radiusMeters: Int = 1500
    ) -> String {
        return """
        [out:json][timeout:25];
        (
          node(around:\(radiusMeters),\(latitude),\(longitude))["leisure"="dog_park"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["amenity"="drinking_water"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["amenity"="waste_basket"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["leisure"="park"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["amenity"="bench"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["natural"="water"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["amenity"="fountain"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["amenity"="place_of_worship"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["natural"="peak"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["natural"="hill"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["tourism"="viewpoint"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["waterway"="waterfall"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["natural"="waterfall"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["tourism"="attraction"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["tourism"="picnic_site"];
          node(around:\(radiusMeters),\(latitude),\(longitude))["leisure"="picnic_table"];
          way(around:\(radiusMeters),\(latitude),\(longitude))["waterway"="waterfall"];
          way(around:\(radiusMeters),\(latitude),\(longitude))["natural"="waterfall"];
        );
        out center body;
        """
    }

    func fetchDogFriendlyPOIs(
        latitude: Double,
        longitude: Double,
        radiusMeters: Int = 1500
    ) async throws -> OverpassResponse {
        let query = Self.buildDogFriendlyQuery(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
        return try await self.query(query)
    }

    static func buildWalkingPathsQuery(
        south: Double,
        west: Double,
        north: Double,
        east: Double
    ) -> String {
        return """
        [out:json][timeout:30];
        (
          way["highway"="footway"](\(south),\(west),\(north),\(east));
          way["highway"="path"](\(south),\(west),\(north),\(east));
          way["highway"="track"](\(south),\(west),\(north),\(east));
          way["highway"="bridleway"](\(south),\(west),\(north),\(east));
          way["highway"="cycleway"](\(south),\(west),\(north),\(east));
          way["highway"="pedestrian"](\(south),\(west),\(north),\(east));
          way["highway"="steps"](\(south),\(west),\(north),\(east));
          way["highway"="unclassified"](\(south),\(west),\(north),\(east));
          way["highway"="residential"](\(south),\(west),\(north),\(east));
          way["highway"="service"](\(south),\(west),\(north),\(east));
          way["highway"="living_street"](\(south),\(west),\(north),\(east));
          way["highway"="tertiary"](\(south),\(west),\(north),\(east));
          way["highway"="secondary"](\(south),\(west),\(north),\(east));
          way["highway"="primary"](\(south),\(west),\(north),\(east));
        );
        out geom;
        """
    }

    func fetchWalkingPaths(
        south: Double,
        west: Double,
        north: Double,
        east: Double
    ) async throws -> OverpassResponse {
        let query = Self.buildWalkingPathsQuery(
            south: south,
            west: west,
            north: north,
            east: east
        )
        return try await self.query(query)
    }

    static func buildFieldBoundaryQuery(
        south: Double,
        west: Double,
        north: Double,
        east: Double
    ) -> String {
        return """
        [out:json][timeout:30];
        (
          way["landuse"="farmland"](\(south),\(west),\(north),\(east));
          way["landuse"="meadow"](\(south),\(west),\(north),\(east));
          way["landuse"="farmyard"](\(south),\(west),\(north),\(east));
          way["landuse"="grass"](\(south),\(west),\(north),\(east));
          way["landuse"="pasture"](\(south),\(west),\(north),\(east));
          way["landuse"="animal_keeping"](\(south),\(west),\(north),\(east));
          way["landuse"="orchard"](\(south),\(west),\(north),\(east));
          way["landuse"="vineyard"](\(south),\(west),\(north),\(east));
          way["landuse"="allotments"](\(south),\(west),\(north),\(east));
          way["landuse"="recreation_ground"](\(south),\(west),\(north),\(east));
          way["natural"="grassland"](\(south),\(west),\(north),\(east));
          way["natural"="scrub"](\(south),\(west),\(north),\(east));
          way["natural"="heath"](\(south),\(west),\(north),\(east));
          way["natural"="moor"](\(south),\(west),\(north),\(east));
          way["natural"="fell"](\(south),\(west),\(north),\(east));
          way["leisure"="park"](\(south),\(west),\(north),\(east));
          way["leisure"="garden"](\(south),\(west),\(north),\(east));
          way["leisure"="golf_course"](\(south),\(west),\(north),\(east));
          way["leisure"="pitch"]["sport"="equestrian"](\(south),\(west),\(north),\(east));
          way["meadow"="agricultural"](\(south),\(west),\(north),\(east));
          way["meadow"="pasture"](\(south),\(west),\(north),\(east));
          way["animal"="sheep"](\(south),\(west),\(north),\(east));
          way["animal"="cattle"](\(south),\(west),\(north),\(east));
          way["animal"="horse"](\(south),\(west),\(north),\(east));
          way["animal"="goat"](\(south),\(west),\(north),\(east));
          way["animal"="pig"](\(south),\(west),\(north),\(east));
          way["animal"="alpaca"](\(south),\(west),\(north),\(east));
          way["animal"="llama"](\(south),\(west),\(north),\(east));
          way["produce"="meat"](\(south),\(west),\(north),\(east));
          way["produce"="milk"](\(south),\(west),\(north),\(east));
          way["produce"="wool"](\(south),\(west),\(north),\(east));
          way["crop"="grass"](\(south),\(west),\(north),\(east));
          way["crop"="hay"](\(south),\(west),\(north),\(east));
          way["crop"="silage"](\(south),\(west),\(north),\(east));
          relation["landuse"="farmland"](\(south),\(west),\(north),\(east));
          relation["landuse"="meadow"](\(south),\(west),\(north),\(east));
          relation["landuse"="farmyard"](\(south),\(west),\(north),\(east));
          relation["landuse"="grass"](\(south),\(west),\(north),\(east));
          relation["landuse"="pasture"](\(south),\(west),\(north),\(east));
          relation["landuse"="animal_keeping"](\(south),\(west),\(north),\(east));
          relation["landuse"="orchard"](\(south),\(west),\(north),\(east));
          relation["natural"="grassland"](\(south),\(west),\(north),\(east));
          relation["natural"="scrub"](\(south),\(west),\(north),\(east));
          relation["natural"="heath"](\(south),\(west),\(north),\(east));
          relation["natural"="moor"](\(south),\(west),\(north),\(east));
        );
        out geom;
        """
    }

    func fetchFieldBoundaries(
        south: Double,
        west: Double,
        north: Double,
        east: Double
    ) async throws -> OverpassResponse {
        let query = Self.buildFieldBoundaryQuery(
            south: south,
            west: west,
            north: north,
            east: east
        )
        return try await self.query(query)
    }
}
