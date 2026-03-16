import SwiftData
import Foundation

@MainActor
class DatabaseContainer {
    static let shared = DatabaseContainer()

    let modelContainer: ModelContainer
    let modelContext: ModelContext

    let walkRepository: WalkRepository
    let poiRepository: PoiRepository
    let dogRepository: DogRepository
    let userRepository: LocalUserRepository
    let cachedPoiRepository: CachedPoiRepository
    let walkSessionRepository: WalkSessionRepository
    let weightRepository: WeightRepository
    let syncQueueRepository: SyncQueueRepository
    let statsRepository: StatsRepository
    let pooBagDropRepository: PooBagDropRepository

    private init() {
        let schema = Schema([
            WalkEntity.self,
            PoiEntity.self,
            DogEntity.self,
            UserEntity.self,
            CachedPoiEntity.self,
            WalkSessionEntity.self,
            TrackPointEntity.self,
            DogWalkJoin.self,
            WeightLogEntity.self,
            SyncQueueEntity.self,
            PooBagDropEntity.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = modelContainer.mainContext

            walkRepository = WalkRepository(modelContext: modelContext)
            poiRepository = PoiRepository(modelContext: modelContext)
            dogRepository = DogRepository(modelContext: modelContext)
            userRepository = LocalUserRepository(modelContext: modelContext)
            cachedPoiRepository = CachedPoiRepository(modelContext: modelContext)
            walkSessionRepository = WalkSessionRepository(modelContext: modelContext)
            weightRepository = WeightRepository(modelContext: modelContext)
            syncQueueRepository = SyncQueueRepository(modelContext: modelContext)
            statsRepository = StatsRepository(modelContext: modelContext)
            pooBagDropRepository = PooBagDropRepository(modelContext: modelContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func performMigrationIfNeeded() {
    }
}
