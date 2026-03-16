# WoofWalk Database Port Summary

## Overview
Android Room database successfully ported to iOS using SwiftData (iOS 17+).

## Database Schema

### Entities (11 total)

1. **WalkEntity**
   - Primary Key: id (String)
   - Fields: userId, startedAt, endedAt, distanceMeters, durationSec, trackJson, polyline, dogIdsJson, syncedToFirestore
   - Conversion: toDomain() / fromDomain()

2. **PoiEntity** (Points of Interest)
   - Primary Key: id (String)
   - Fields: type, title, desc, lat, lng, geohash, photoUrls, createdBy, createdAt, updatedAt, status, voteUp, voteDown, regionCode, expiresAt, access fields, address fields
   - Conversion: toDomain() / fromDomain()

3. **DogEntity**
   - Primary Key: dogId (String)
   - Fields: ownerUid, name, breed, birthdateEpochDays, sex, color, photoUrl, createdAt, updatedAt, isArchived, nervousDog, warningNote
   - Conversion: toDomain()

4. **UserEntity**
   - Primary Key: id (String)
   - Fields: username, email, photoUrl, pawPoints, level, badgesJson, dogsJson, createdAt, regionCode, lastSyncedAt
   - Conversion: toDomain() / fromDomain()

5. **CachedPoiEntity** (OSM POI Cache)
   - Primary Key: id (Int64, auto-generated)
   - Unique: osmId (String)
   - Fields: name, type, latitude, longitude, tags, cachedAt, regionLat, regionLng, radiusMeters

6. **WalkSessionEntity**
   - Primary Key: sessionId (String)
   - Fields: startedAt, endedAt, distanceMeters, durationSec, avgPaceSecPerKm, notes

7. **TrackPointEntity**
   - Primary Key: id (String)
   - Fields: sessionId, lat, lng, accMeters, timestamp

8. **DogWalkJoin** (Many-to-Many relationship)
   - Composite Key: dogId + sessionId
   - Foreign Keys: dogId → DogEntity, sessionId → WalkSessionEntity

9. **WeightLogEntity**
   - Composite Key: dogId + loggedAt
   - Fields: weightKg

10. **SyncQueueEntity**
    - Primary Key: id (Int64, auto-generated)
    - Fields: entityType, entityId, operation, data, timestamp, retryCount, lastError
    - Constants: EntityType (poi, walk, comment, vote), Operation (create, update, delete)

11. **PooBagDropEntity**
    - Primary Key: id (String)
    - Fields: latitude, longitude, timestamp, notes, isCollected, collectedAt

## Repositories (10 total)

### 1. WalkRepository
**Methods:**
- insert(_ walk: WalkEntity)
- insertAll(_ walks: [WalkEntity])
- update(_ walk: WalkEntity)
- getWalkById(_ walkId: String) -> WalkEntity?
- getUserWalks(_ userId: String) -> [WalkEntity]
- getRecentWalks(_ userId: String, limit: Int) -> [WalkEntity]
- getUnsyncedWalks() -> [WalkEntity]
- markAsSynced(_ walkId: String)
- getTotalDistance(_ userId: String) -> Int
- getTotalDuration(_ userId: String) -> Int
- getWalkCount(_ userId: String) -> Int
- getWalksInDateRange(userId: String, startTime: Date, endTime: Date) -> [WalkEntity]
- deleteById(_ walkId: String)
- deleteUserWalks(_ userId: String)
- deleteAll()

### 2. PoiRepository
**Methods:**
- insert(_ poi: PoiEntity)
- insertAll(_ pois: [PoiEntity])
- update(_ poi: PoiEntity)
- getPoiById(_ poiId: String) -> PoiEntity?
- getAllActivePois() -> [PoiEntity]
- getPoisInBounds(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) -> [PoiEntity]
- getPoisByGeohashPrefix(_ prefix: String) -> [PoiEntity]
- getPoisByType(_ type: String) -> [PoiEntity]
- getUserPois(_ userId: String) -> [PoiEntity]
- deleteById(_ poiId: String)
- deleteExpired(_ currentTime: Date)
- deleteAll()
- getCount() -> Int

### 3. DogRepository
**Methods:**
- upsert(_ dog: DogEntity)
- upsertAll(_ dogs: [DogEntity])
- update(_ dog: DogEntity)
- dogsFlow() -> [DogEntity]
- get(_ id: String) -> DogEntity?
- getDogFlow(_ id: String) -> DogEntity?
- dogsByOwner(_ ownerUid: String) -> [DogEntity]
- archive(_ id: String, timestamp: Date)
- delete(_ id: String)

### 4. UserRepository
**Methods:**
- insert(_ user: UserEntity)
- update(_ user: UserEntity)
- getUserById(_ userId: String) -> UserEntity?
- getUserByEmail(_ email: String) -> UserEntity?
- addPawPoints(userId: String, points: Int)
- updateLevel(userId: String, level: Int)
- updateLastSyncedAt(userId: String, timestamp: Date)
- getLastSyncedAt(_ userId: String) -> Date?
- deleteById(_ userId: String)
- deleteAll()
- getCount() -> Int

### 5. CachedPoiRepository
**Methods:**
- getPoisInBounds(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double, minCacheTime: Date) -> [CachedPoiEntity]
- insertPois(_ pois: [CachedPoiEntity])
- deleteExpiredPois(_ minCacheTime: Date)
- getPoisByRegion(lat: Double, lng: Double, radius: Double, minCacheTime: Date) -> [CachedPoiEntity]
- getCount() -> Int
- deleteAll()

### 6. WalkSessionRepository
**Methods:**
- insertSession(_ session: WalkSessionEntity)
- updateSession(_ session: WalkSessionEntity)
- insertJoin(_ join: DogWalkJoin)
- insertJoins(_ joins: [DogWalkJoin])
- insertPoints(_ points: [TrackPointEntity])
- insertPoint(_ point: TrackPointEntity)
- getSession(_ id: String) -> WalkSessionEntity?
- getActiveSession() -> WalkSessionEntity?
- sessionsForDog(_ dogId: String) -> [WalkSessionEntity]
- recentSessionsForDog(_ dogId: String, limit: Int) -> [WalkSessionEntity]
- getTrackPoints(_ sessionId: String) -> [TrackPointEntity]
- getDogsForSession(_ sessionId: String) -> [String]
- deleteTrackPoints(_ sessionId: String)
- deleteDogWalkJoins(_ sessionId: String)
- deleteSession(_ sessionId: String)
- getWalksCompletedOnDate(startOfDay: Date, endOfDay: Date) -> Int
- hasWalksOnDate(startOfDay: Date, endOfDay: Date) -> Bool

### 7. WeightRepository
**Methods:**
- upsert(_ log: WeightLogEntity)
- weights(_ dogId: String) -> [WeightLogEntity]
- getLatestWeight(_ dogId: String) -> WeightLogEntity?
- deleteWeight(dogId: String, timestamp: Date)

### 8. SyncQueueRepository
**Methods:**
- getAllPending() -> [SyncQueueEntity]
- getPendingBatch() -> [SyncQueueEntity]
- insert(_ item: SyncQueueEntity) -> Int64
- update(_ item: SyncQueueEntity)
- delete(_ item: SyncQueueEntity)
- deleteById(_ id: Int64)
- deleteByEntity(type: String, id: String)
- getPendingCount() -> Int
- clearFailedItems()
- incrementRetry(id: Int64, error: String)

### 9. StatsRepository
**Methods:**
- weeklyStats(dogId: String, limitRows: Int) -> [WeeklyRow]
- monthlyStats(dogId: String, limitRows: Int) -> [MonthlyRow]
- totalWalksForDog(_ dogId: String) -> Int
- totalDistanceForDog(_ dogId: String) -> Double
- totalDurationForDog(_ dogId: String) -> Int64
- getAllCompletedSessions() -> [WalkSessionEntity]
- getTotalWalkCount() -> Int
- getTotalDistance() -> Double
- getTotalDuration() -> Int64
- getWeeklyWalkCounts() -> [DailyWalkCount]

**Supporting Types:**
- WeeklyRow: dogId, yearWeek, totalDistanceMeters, totalDurationSec, walkCount
- MonthlyRow: dogId, yearMonth, totalDistanceMeters, totalDurationSec, walkCount
- DailyWalkCount: dayOfWeek, walkCount

### 10. PooBagDropRepository
**Methods:**
- getActiveBagDrops() -> [PooBagDropEntity]
- getCollectedBagDrops() -> [PooBagDropEntity]
- insert(_ drop: PooBagDropEntity)
- markAsCollected(id: String, collectedAt: Date)
- delete(id: String)
- deleteOldCollected(cutoffTime: Date)

## Database Container

**DatabaseContainer** (Singleton)
- Manages SwiftData ModelContainer and ModelContext
- Provides singleton access to all repositories
- Initialized once at app startup
- All repositories use @MainActor for thread-safety

## Key Differences from Android

1. **Flow → Arrays**: Android's Flow<T> reactive streams replaced with synchronous array returns. iOS layer should wrap with Combine/AsyncStream if reactive behavior needed.

2. **Suspend → Throws**: Kotlin coroutines (suspend) replaced with Swift error handling (throws).

3. **Long → Int64/Date**: Android epoch milliseconds (Long) converted to Swift Date objects.

4. **Indices**: SwiftData handles indexing automatically; Room's @Index annotations replaced with @Attribute(.unique) where needed.

5. **Foreign Keys**: SwiftData doesn't enforce declarative foreign keys like Room. Cascade deletes must be handled manually in repository logic.

6. **Migrations**: Room migrations (MIGRATION_4_5, etc.) not needed initially. SwiftData handles lightweight migrations automatically. Complex migrations require custom logic in performMigrationIfNeeded().

## Usage Example

```swift
@MainActor
class WalkService {
    private let walkRepo = DatabaseContainer.shared.walkRepository

    func saveWalk(_ walk: WalkHistory) throws {
        let entity = WalkEntity.fromDomain(walk)
        try walkRepo.insert(entity)
    }

    func getUserWalks(userId: String) throws -> [WalkHistory] {
        let entities = try walkRepo.getUserWalks(userId)
        return entities.map { $0.toDomain() }
    }
}
```

## Migration Notes

- Android database version 7 schema fully ported
- All indices from Room preserved in SwiftData predicates
- JSON serialization (Gson) replaced with JSONEncoder/JSONDecoder
- Geohash queries use String.starts(with:) predicate
- Complex SQL queries (StatsDao) reimplemented with in-memory grouping using Swift Dictionary

## Files Created

### Entities (11 files)
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/WalkEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/PoiEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/DogEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/UserEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/CachedPoiEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/WalkSessionEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/TrackPointEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/DogWalkJoin.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/WeightLogEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/SyncQueueEntity.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Entities/PooBagDropEntity.swift

### Repositories (10 files)
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/WalkRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/PoiRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/DogRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/UserRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/CachedPoiRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/WalkSessionRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/WeightRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/SyncQueueRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/StatsRepository.swift
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/Repositories/PooBagDropRepository.swift

### Container (1 file)
- /mnt/c/app/WoofWalkiOS/WoofWalk/Database/DatabaseContainer.swift

## Next Steps

1. Add domain model files referenced in entity conversions (WalkHistory, Poi, DogProfile, UserProfile, AccessInfo, TrackPoint)
2. Integrate DatabaseContainer into app initialization
3. Add Combine publishers or AsyncStream wrappers if reactive data flow needed
4. Implement proper error handling and logging
5. Add unit tests for repositories
6. Consider adding database versioning/migration strategy for future schema changes
