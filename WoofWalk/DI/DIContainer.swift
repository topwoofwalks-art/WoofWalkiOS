#if false
import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

final class DIContainer {
    static let shared = DIContainer()

    private var singletons: [String: Any] = [:]
    private let lock = NSLock()

    private init() {
        registerServices()
    }

    private func registerServices() {
        registerFirebaseServices()
        registerNetworkServices()
        registerDataServices()
        registerLocationServices()
        registerUtilityServices()
        registerRepositories()
        registerNewFeatureServices()
    }

    private func registerFirebaseServices() {
        register(Auth.self, singleton: true) {
            Auth.auth()
        }

        register(Firestore.self, singleton: true) {
            let db = Firestore.firestore()
            let settings = FirestoreSettings()
            settings.isPersistenceEnabled = true
            settings.cacheSizeBytes = 10 * 1024 * 1024
            db.settings = settings
            return db
        }

        register(Storage.self, singleton: true) {
            Storage.storage()
        }
    }

    private func registerNetworkServices() {
        register(URLSession.self, singleton: true) {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10
            config.timeoutIntervalForResource = 15
            config.httpMaximumConnectionsPerHost = 5
            config.requestCachePolicy = .useProtocolCachePolicy
            return URLSession(configuration: config)
        }

        register(OsrmService.self, singleton: true) {
            OsrmService(session: self.resolve())
        }

        register(OverpassService.self, singleton: true) {
            OverpassService(session: self.resolve())
        }

        register(DirectionsService.self, singleton: true) {
            DirectionsService(session: self.resolve())
        }
    }

    private func registerDataServices() {
        register(WoofWalkDatabase.self, singleton: true) {
            WoofWalkDatabase.shared
        }
    }

    private func registerLocationServices() {
        register(CLLocationManager.self, singleton: false) {
            CLLocationManager()
        }

        register(LocationService.self, singleton: true) {
            LocationService()
        }
    }

    private func registerUtilityServices() {
        register(UserDataStore.self, singleton: true) {
            UserDataStore()
        }

        register(ImageCompressor.self, singleton: true) {
            ImageCompressor()
        }

        register(NotificationHelper.self, singleton: true) {
            NotificationHelper()
        }

        register(GeofenceManager.self, singleton: true) {
            GeofenceManager(
                locationService: self.resolve(),
                poiRepository: self.resolve()
            )
        }

        register(StorageManager.self, singleton: true) {
            StorageManager(storage: self.resolve())
        }

        register(FcmManager.self, singleton: true) {
            FcmManager(
                firestore: self.resolve(),
                auth: self.resolve()
            )
        }
    }

    private func registerRepositories() {
        register(UserRepository.self, singleton: true) {
            UserRepository(
                auth: self.resolve(),
                firestore: self.resolve(),
                userDao: self.resolve(WoofWalkDatabase.self).userDao
            )
        }

        register(DogRepository.self, singleton: true) {
            DogRepository(
                dogDao: self.resolve(WoofWalkDatabase.self).dogDao,
                firestore: self.resolve(),
                auth: self.resolve(),
                storage: self.resolve()
            )
        }

        register(WalkRepository.self, singleton: true) {
            WalkRepository(
                walkDao: self.resolve(WoofWalkDatabase.self).walkDao,
                firestore: self.resolve(),
                auth: self.resolve()
            )
        }

        register(WalkSessionRepository.self, singleton: true) {
            WalkSessionRepository(
                walkSessionDao: self.resolve(WoofWalkDatabase.self).walkSessionDao,
                firestore: self.resolve(),
                auth: self.resolve()
            )
        }

        register(PoiRepository.self, singleton: true) {
            PoiRepository(
                poiDao: self.resolve(WoofWalkDatabase.self).poiDao,
                firestore: self.resolve(),
                auth: self.resolve(),
                overpassService: self.resolve()
            )
        }

        register(PoiCacheRepository.self, singleton: true) {
            PoiCacheRepository(
                cachedPoiDao: self.resolve(WoofWalkDatabase.self).cachedPoiDao,
                overpassService: self.resolve()
            )
        }

        register(RouteRepository.self, singleton: true) {
            RouteRepository(
                osrmService: self.resolve(),
                directionsService: self.resolve()
            )
        }

        register(DirectionsRepository.self, singleton: true) {
            DirectionsRepository(
                directionsService: self.resolve()
            )
        }

        register(PooBagDropRepository.self, singleton: true) {
            PooBagDropRepository(
                pooBagDropDao: self.resolve(WoofWalkDatabase.self).pooBagDropDao,
                firestore: self.resolve(),
                auth: self.resolve()
            )
        }

        register(PublicDogRepository.self, singleton: true) {
            PublicDogRepository(
                firestore: self.resolve(),
                auth: self.resolve()
            )
        }

        register(LostDogRepository.self, singleton: true) {
            LostDogRepository(
                firestore: self.resolve(),
                auth: self.resolve(),
                storage: self.resolve()
            )
        }

        register(FriendRepository.self, singleton: true) {
            FriendRepository(
                firestore: self.resolve(),
                auth: self.resolve()
            )
        }

        register(ChatRepository.self, singleton: true) {
            ChatRepository(
                firestore: self.resolve(),
                auth: self.resolve()
            )
        }

        register(FeedRepository.self, singleton: true) {
            FeedRepository(
                firestore: self.resolve(),
                auth: self.resolve(),
                storage: self.resolve()
            )
        }

        register(EventRepository.self, singleton: true) {
            EventRepository(
                firestore: self.resolve(),
                auth: self.resolve()
            )
        }
    }

    private func registerNewFeatureServices() {
        // Repositories
        register(CharityRepository.self, singleton: true) {
            CharityRepository()
        }

        register(ChallengeRepository.self, singleton: true) {
            ChallengeRepository()
        }

        register(LeagueRepository.self, singleton: true) {
            LeagueRepository()
        }

        register(MilestoneRepository.self, singleton: true) {
            MilestoneRepository()
        }

        register(DiscoveryRepository.self, singleton: true) {
            DiscoveryRepository()
        }

        // Services
        register(BadgeAwardingService.self, singleton: true) {
            BadgeAwardingService.shared
        }

        register(ShareService.self, singleton: true) {
            ShareService.shared
        }

        register(MapSnapshotCache.self, singleton: true) {
            MapSnapshotCache.shared
        }

        register(AppUpdateChecker.self, singleton: true) {
            AppUpdateChecker.shared
        }

        // Navigation
        register(AppNavigator.self, singleton: true) {
            AppNavigator.shared
        }
    }

    func register<T>(_ type: T.Type, singleton: Bool = false, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }

        if singleton {
            singletons[key] = factory()
        } else {
            singletons[key] = factory
        }
    }

    func resolve<T>(_ type: T.Type = T.self) -> T {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }

        if let instance = singletons[key] as? T {
            return instance
        }

        if let factory = singletons[key] as? () -> T {
            return factory()
        }

        fatalError("No registration found for type: \(key)")
    }

    func resolveOptional<T>(_ type: T.Type = T.self) -> T? {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }

        if let instance = singletons[key] as? T {
            return instance
        }

        if let factory = singletons[key] as? () -> T {
            return factory()
        }

        return nil
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        singletons.removeAll()
        registerServices()
    }
}

extension DIContainer {
    static func makeEnvironmentObjects() -> some View {
        EmptyView()
            .environmentObject(resolve(UserRepository.self))
            .environmentObject(resolve(DogRepository.self))
            .environmentObject(resolve(WalkRepository.self))
            .environmentObject(resolve(LocationService.self))
            .environmentObject(resolve(BadgeAwardingService.self))
            .environmentObject(resolve(AppNavigator.self))
    }
}
#endif
