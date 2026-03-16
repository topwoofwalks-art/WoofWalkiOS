import Foundation
import CoreLocation

class OsmPoiCache {
    private struct CacheEntry {
        let pois: [POI]
        let timestamp: Date
        let center: CLLocationCoordinate2D
        let radiusMeters: Int
    }

    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "com.woofwalk.osmpoicache", attributes: .concurrent)

    static let cacheTTL: TimeInterval = 30 * 60
    static let maxCacheSize = 20

    func get(center: CLLocationCoordinate2D, radiusMeters: Int) -> [POI]? {
        return queue.sync {
            let geohash = Geohash.encode(latitude: center.latitude, longitude: center.longitude, precision: 6)
            guard let entry = cache[geohash] else {
                print("OsmPoiCache MISS (not found): \(geohash)")
                return nil
            }

            let now = Date()
            let isExpired = now.timeIntervalSince(entry.timestamp) > Self.cacheTTL

            if isExpired {
                queue.async(flags: .barrier) {
                    self.cache.removeValue(forKey: geohash)
                }
                print("OsmPoiCache MISS (expired): \(geohash)")
                return nil
            }

            let distance = haversineDistance(from: entry.center, to: center)
            let radiusKm = Double(radiusMeters) / 1000.0
            if distance > radiusKm * 0.5 {
                print("OsmPoiCache MISS (moved): \(geohash), distance=\(distance)km")
                return nil
            }

            if entry.radiusMeters < radiusMeters {
                print("OsmPoiCache MISS (radius too small): cached=\(entry.radiusMeters)m, requested=\(radiusMeters)m")
                return nil
            }

            print("OsmPoiCache HIT: \(geohash), \(entry.pois.count) POIs from cache")
            return entry.pois
        }
    }

    func put(center: CLLocationCoordinate2D, radiusMeters: Int, pois: [POI]) {
        queue.async(flags: .barrier) {
            let geohash = Geohash.encode(latitude: center.latitude, longitude: center.longitude, precision: 6)

            if self.cache.count >= Self.maxCacheSize {
                if let oldestKey = self.cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
                    self.cache.removeValue(forKey: oldestKey)
                    print("OsmPoiCache EVICT: \(oldestKey)")
                }
            }

            self.cache[geohash] = CacheEntry(
                pois: pois,
                timestamp: Date(),
                center: center,
                radiusMeters: radiusMeters
            )
            print("OsmPoiCache PUT: \(geohash), \(pois.count) POIs cached")
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            print("OsmPoiCache CLEAR")
        }
    }

    func evictExpired() {
        queue.async(flags: .barrier) {
            let now = Date()
            let toRemove = self.cache.filter { now.timeIntervalSince($0.value.timestamp) > Self.cacheTTL }
                .map { $0.key }

            toRemove.forEach { self.cache.removeValue(forKey: $0) }
            if !toRemove.isEmpty {
                print("OsmPoiCache EVICT_EXPIRED: \(toRemove.count) entries")
            }
        }
    }

    struct CacheStats {
        let size: Int
        let totalPois: Int
    }

    func getStats() -> CacheStats {
        return queue.sync {
            CacheStats(
                size: cache.count,
                totalPois: cache.values.reduce(0) { $0 + $1.pois.count }
            )
        }
    }

    private func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadiusKm = 6371.0

        let dLat = (to.latitude - from.latitude) * .pi / 180.0
        let dLng = (to.longitude - from.longitude) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(from.latitude * .pi / 180.0) * cos(to.latitude * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusKm * c
    }
}
