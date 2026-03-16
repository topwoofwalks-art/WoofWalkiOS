import SwiftData
import Foundation

@MainActor
class PoiRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func insert(_ poi: PoiEntity) throws {
        modelContext.insert(poi)
        try modelContext.save()
    }

    func insertAll(_ pois: [PoiEntity]) throws {
        for poi in pois {
            modelContext.insert(poi)
        }
        try modelContext.save()
    }

    func update(_ poi: PoiEntity) throws {
        try modelContext.save()
    }

    func getPoiById(_ poiId: String) throws -> PoiEntity? {
        let descriptor = FetchDescriptor<PoiEntity>(
            predicate: #Predicate { $0.id == poiId }
        )
        return try modelContext.fetch(descriptor).first
    }

    func getAllActivePois() throws -> [PoiEntity] {
        let descriptor = FetchDescriptor<PoiEntity>(
            predicate: #Predicate { $0.status == "ACTIVE" }
        )
        return try modelContext.fetch(descriptor)
    }

    func getPoisInBounds(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) throws -> [PoiEntity] {
        let descriptor = FetchDescriptor<PoiEntity>(
            predicate: #Predicate { poi in
                poi.lat >= minLat &&
                poi.lat <= maxLat &&
                poi.lng >= minLng &&
                poi.lng <= maxLng &&
                poi.status == "ACTIVE"
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func getPoisByGeohashPrefix(_ prefix: String) throws -> [PoiEntity] {
        let descriptor = FetchDescriptor<PoiEntity>(
            predicate: #Predicate { poi in
                poi.geohash.starts(with: prefix) && poi.status == "ACTIVE"
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func getPoisByType(_ type: String) throws -> [PoiEntity] {
        let descriptor = FetchDescriptor<PoiEntity>(
            predicate: #Predicate { poi in
                poi.type == type && poi.status == "ACTIVE"
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func getUserPois(_ userId: String) throws -> [PoiEntity] {
        let descriptor = FetchDescriptor<PoiEntity>(
            predicate: #Predicate { $0.createdBy == userId }
        )
        return try modelContext.fetch(descriptor)
    }

    func deleteById(_ poiId: String) throws {
        if let poi = try getPoiById(poiId) {
            modelContext.delete(poi)
            try modelContext.save()
        }
    }

    func deleteExpired(_ currentTime: Date) throws {
        let descriptor = FetchDescriptor<PoiEntity>(
            predicate: #Predicate { poi in
                poi.expiresAt != nil && poi.expiresAt! < currentTime
            }
        )
        let expiredPois = try modelContext.fetch(descriptor)
        for poi in expiredPois {
            modelContext.delete(poi)
        }
        try modelContext.save()
    }

    func deleteAll() throws {
        try modelContext.delete(model: PoiEntity.self)
        try modelContext.save()
    }

    func getCount() throws -> Int {
        let descriptor = FetchDescriptor<PoiEntity>()
        return try modelContext.fetchCount(descriptor)
    }
}
