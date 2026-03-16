import SwiftData
import Foundation

@MainActor
class CachedPoiRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getPoisInBounds(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        minCacheTime: Date
    ) throws -> [CachedPoiEntity] {
        let descriptor = FetchDescriptor<CachedPoiEntity>(
            predicate: #Predicate { poi in
                poi.latitude >= minLat &&
                poi.latitude <= maxLat &&
                poi.longitude >= minLng &&
                poi.longitude <= maxLng &&
                poi.cachedAt >= minCacheTime
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func insertPois(_ pois: [CachedPoiEntity]) throws {
        for poi in pois {
            modelContext.insert(poi)
        }
        try modelContext.save()
    }

    func deleteExpiredPois(_ minCacheTime: Date) throws {
        let descriptor = FetchDescriptor<CachedPoiEntity>(
            predicate: #Predicate { $0.cachedAt < minCacheTime }
        )
        let expiredPois = try modelContext.fetch(descriptor)
        for poi in expiredPois {
            modelContext.delete(poi)
        }
        try modelContext.save()
    }

    func getPoisByRegion(
        lat: Double,
        lng: Double,
        radius: Double,
        minCacheTime: Date
    ) throws -> [CachedPoiEntity] {
        let descriptor = FetchDescriptor<CachedPoiEntity>(
            predicate: #Predicate { poi in
                poi.regionLat == lat &&
                poi.regionLng == lng &&
                poi.radiusMeters == radius &&
                poi.cachedAt >= minCacheTime
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func getCount() throws -> Int {
        let descriptor = FetchDescriptor<CachedPoiEntity>()
        return try modelContext.fetchCount(descriptor)
    }

    func deleteAll() throws {
        try modelContext.delete(model: CachedPoiEntity.self)
        try modelContext.save()
    }
}
