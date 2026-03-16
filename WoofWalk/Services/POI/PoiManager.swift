import Foundation
import CoreLocation

struct CacheStats {
    let totalCachedPois: Int
    let cacheHitRate: Double
    let lastUpdated: Date
}

class PoiManager {
    static let shared = PoiManager()

    private let overpassService = OverpassService()
    private let memoryCache = OsmPoiCache()
    private let databaseManager = PoiDatabaseManager.shared

    private let cacheExpirationDays = 7
    private let earthRadiusKm = 6371.0
    private let cacheRegionOverlap = 0.8

    private var totalRequests: Int = 0
    private var cacheHits: Int = 0

    private init() {}

    func fetchPoisWithCache(
        lat: Double,
        lng: Double,
        radiusKm: Double
    ) async throws -> [POI] {
        totalRequests += 1

        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let radiusMeters = Int(radiusKm * 1000)

        if let cachedPois = memoryCache.get(center: center, radiusMeters: radiusMeters) {
            cacheHits += 1
            print("Memory cache HIT: \(cachedPois.count) POIs")
            return cachedPois
        }

        let minCacheTime = Calendar.current.date(
            byAdding: .day,
            value: -cacheExpirationDays,
            to: Date()
        ) ?? Date()

        let bounds = calculateBounds(lat: lat, lng: lng, radiusKm: radiusKm)
        let cachedPoiEntities = databaseManager.getCachedPoisInBounds(
            minLat: bounds.minLat,
            maxLat: bounds.maxLat,
            minLng: bounds.minLng,
            maxLng: bounds.maxLng,
            minCacheTime: minCacheTime
        )

        if hasSufficientCoverage(
            cachedPois: cachedPoiEntities,
            targetLat: lat,
            targetLng: lng,
            targetRadiusKm: radiusKm
        ) {
            cacheHits += 1
            let pois = cachedPoiEntities.map { $0.toDomainPoi() }
            print("Database cache HIT: \(pois.count) POIs from database")

            memoryCache.put(center: center, radiusMeters: radiusMeters, pois: pois)

            return pois
        }

        print("Cache MISS: Fetching from Overpass API (lat=\(lat), lng=\(lng), radius=\(radiusKm)km)")

        let query = OverpassService.buildDogFriendlyQuery(
            lat: lat,
            lng: lng,
            radiusMeters: radiusMeters
        )

        let response = try await overpassService.query(query)

        let newCachedPois = response.elements.map { element in
            CachedPoi(
                osmId: "osm_\(element.id)",
                name: element.tags?["name"] ?? "",
                type: OverpassService.mapOsmTypeToPoiType(tags: element.tags),
                latitude: element.lat,
                longitude: element.lon,
                tags: element.tags?.map { "\($0.key)=\($0.value)" }.joined(separator: ";") ?? "",
                cachedAt: Date(),
                regionLat: lat,
                regionLng: lng,
                radiusKm: radiusKm
            )
        }

        if !newCachedPois.isEmpty {
            try databaseManager.saveCachedPois(newCachedPois)
            print("Cached \(newCachedPois.count) POIs from Overpass API")
        }

        let pois = newCachedPois.map { $0.toDomainPoi() }

        memoryCache.put(center: center, radiusMeters: radiusMeters, pois: pois)

        return pois
    }

    func clearExpiredCache() -> Int {
        let minCacheTime = Calendar.current.date(
            byAdding: .day,
            value: -cacheExpirationDays,
            to: Date()
        ) ?? Date()

        let countBefore = databaseManager.getCount()
        databaseManager.deleteExpiredPois(minCacheTime: minCacheTime)
        let countAfter = databaseManager.getCount()

        let deletedCount = countBefore - countAfter
        print("Cleared \(deletedCount) expired POIs from cache")

        return deletedCount
    }

    func getCacheStats() -> CacheStats {
        let count = databaseManager.getCount()
        let hitRate = totalRequests > 0 ? (Double(cacheHits) / Double(totalRequests)) * 100.0 : 0.0

        print("Cache stats: \(count) POIs, hit rate: \(String(format: "%.2f", hitRate))% (\(cacheHits)/\(totalRequests))")

        return CacheStats(
            totalCachedPois: count,
            cacheHitRate: hitRate,
            lastUpdated: Date()
        )
    }

    func clearMemoryCache() {
        memoryCache.clear()
    }

    func evictExpiredFromMemory() {
        memoryCache.evictExpired()
    }

    private struct GeoBounds {
        let minLat: Double
        let maxLat: Double
        let minLng: Double
        let maxLng: Double
    }

    private func calculateBounds(lat: Double, lng: Double, radiusKm: Double) -> GeoBounds {
        let latDelta = radiusKm / earthRadiusKm * (180.0 / .pi)
        let lngDelta = radiusKm / (earthRadiusKm * cos(lat * .pi / 180.0)) * (180.0 / .pi)

        return GeoBounds(
            minLat: lat - latDelta,
            maxLat: lat + latDelta,
            minLng: lng - lngDelta,
            maxLng: lng + lngDelta
        )
    }

    private func hasSufficientCoverage(
        cachedPois: [CachedPoi],
        targetLat: Double,
        targetLng: Double,
        targetRadiusKm: Double
    ) -> Bool {
        guard !cachedPois.isEmpty else { return false }

        let cachedRegions = Set(cachedPois.map {
            "\($0.regionLat)_\($0.regionLng)_\($0.radiusKm)"
        })

        for regionKey in cachedRegions {
            let parts = regionKey.split(separator: "_")
            guard parts.count == 3,
                  let regionLat = Double(parts[0]),
                  let regionLng = Double(parts[1]),
                  let regionRadius = Double(parts[2]) else {
                continue
            }

            let distance = haversineDistance(
                lat1: targetLat, lng1: targetLng,
                lat2: regionLat, lng2: regionLng
            )
            let effectiveRadius = regionRadius * cacheRegionOverlap

            if distance <= effectiveRadius && regionRadius >= targetRadiusKm * 0.9 {
                return true
            }
        }

        return false
    }

    private func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLng = (lng2 - lng1) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusKm * c
    }
}
