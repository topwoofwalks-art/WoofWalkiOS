import Foundation
import CoreData
import CoreLocation

class PoiDatabaseManager {
    static let shared = PoiDatabaseManager()

    private let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "WoofWalk")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Failed to load Core Data: \(error)")
            }
        }
    }

    func saveCachedPoi(_ cachedPoi: CachedPoi) throws {
        let context = container.viewContext
        let entity = CachedPoiEntity(context: context)

        entity.osmId = cachedPoi.osmId
        entity.name = cachedPoi.name
        entity.type = cachedPoi.type
        entity.latitude = cachedPoi.latitude
        entity.longitude = cachedPoi.longitude
        entity.tags = cachedPoi.tags
        entity.cachedAt = cachedPoi.cachedAt
        entity.regionLat = cachedPoi.regionLat
        entity.regionLng = cachedPoi.regionLng
        entity.radiusKm = cachedPoi.radiusKm

        try context.save()
    }

    func saveCachedPois(_ cachedPois: [CachedPoi]) throws {
        let context = container.viewContext

        for cachedPoi in cachedPois {
            let entity = CachedPoiEntity(context: context)

            entity.osmId = cachedPoi.osmId
            entity.name = cachedPoi.name
            entity.type = cachedPoi.type
            entity.latitude = cachedPoi.latitude
            entity.longitude = cachedPoi.longitude
            entity.tags = cachedPoi.tags
            entity.cachedAt = cachedPoi.cachedAt
            entity.regionLat = cachedPoi.regionLat
            entity.regionLng = cachedPoi.regionLng
            entity.radiusKm = cachedPoi.radiusKm
        }

        try context.save()
    }

    func getCachedPoisInBounds(
        minLat: Double,
        maxLat: Double,
        minLng: Double,
        maxLng: Double,
        minCacheTime: Date
    ) -> [CachedPoi] {
        let context = container.viewContext
        let request: NSFetchRequest<CachedPoiEntity> = CachedPoiEntity.fetchRequest()

        request.predicate = NSPredicate(
            format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f AND cachedAt >= %@",
            minLat, maxLat, minLng, maxLng, minCacheTime as NSDate
        )

        do {
            let results = try context.fetch(request)
            return results.map { entity in
                CachedPoi(
                    osmId: entity.osmId ?? "",
                    name: entity.name ?? "",
                    type: entity.type ?? "",
                    latitude: entity.latitude,
                    longitude: entity.longitude,
                    tags: entity.tags ?? "",
                    cachedAt: entity.cachedAt ?? Date(),
                    regionLat: entity.regionLat,
                    regionLng: entity.regionLng,
                    radiusKm: entity.radiusKm
                )
            }
        } catch {
            print("Failed to fetch cached POIs: \(error)")
            return []
        }
    }

    func deleteExpiredPois(minCacheTime: Date) {
        let context = container.viewContext
        let request: NSFetchRequest<CachedPoiEntity> = CachedPoiEntity.fetchRequest()

        request.predicate = NSPredicate(format: "cachedAt < %@", minCacheTime as NSDate)

        do {
            let results = try context.fetch(request)
            for entity in results {
                context.delete(entity)
            }
            try context.save()
        } catch {
            print("Failed to delete expired POIs: \(error)")
        }
    }

    func getCount() -> Int {
        let context = container.viewContext
        let request: NSFetchRequest<CachedPoiEntity> = CachedPoiEntity.fetchRequest()

        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count POIs: \(error)")
            return 0
        }
    }
}

@objc(CachedPoiEntity)
class CachedPoiEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CachedPoiEntity> {
        return NSFetchRequest<CachedPoiEntity>(entityName: "CachedPoiEntity")
    }

    @NSManaged var osmId: String?
    @NSManaged var name: String?
    @NSManaged var type: String?
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var tags: String?
    @NSManaged var cachedAt: Date?
    @NSManaged var regionLat: Double
    @NSManaged var regionLng: Double
    @NSManaged var radiusKm: Double
}
