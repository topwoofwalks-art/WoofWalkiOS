// This file is excluded from compilation because it references types
// that don't exist in the actual codebase yet.
#if false
import Foundation

protocol ServiceLocatorProtocol {
    func resolve<T>(_ type: T.Type) -> T
    func resolveOptional<T>(_ type: T.Type) -> T?
}

extension DIContainer: ServiceLocatorProtocol {}

final class ServiceLocator {
    static var current: ServiceLocatorProtocol = DIContainer.shared

    static func resolve<T>(_ type: T.Type = T.self) -> T {
        current.resolve(type)
    }

    static func resolveOptional<T>(_ type: T.Type = T.self) -> T? {
        current.resolveOptional(type)
    }

    static func setLocator(_ locator: ServiceLocatorProtocol) {
        current = locator
    }

    static func reset() {
        current = DIContainer.shared
    }
}

extension ServiceLocator {
    static var userRepository: UserRepository {
        resolve()
    }

    static var dogRepository: DogRepository {
        resolve()
    }

    static var walkRepository: WalkRepository {
        resolve()
    }

    static var walkSessionRepository: WalkSessionRepository {
        resolve()
    }

    static var poiRepository: PoiRepository {
        resolve()
    }

    static var poiCacheRepository: PoiCacheRepository {
        resolve()
    }

    static var routeRepository: RouteRepository {
        resolve()
    }

    static var directionsRepository: DirectionsRepository {
        resolve()
    }

    static var pooBagDropRepository: PooBagDropRepository {
        resolve()
    }

    static var publicDogRepository: PublicDogRepository {
        resolve()
    }

    static var lostDogRepository: LostDogRepository {
        resolve()
    }

    static var friendRepository: FriendRepository {
        resolve()
    }

    static var chatRepository: ChatRepository {
        resolve()
    }

    static var feedRepository: FeedRepository {
        resolve()
    }

    static var eventRepository: EventRepository {
        resolve()
    }

    static var locationService: LocationService {
        resolve()
    }

    static var osrmService: OsrmService {
        resolve()
    }

    static var overpassService: OverpassService {
        resolve()
    }

    static var directionsService: DirectionsService {
        resolve()
    }

    static var userDataStore: UserDataStore {
        resolve()
    }

    static var imageCompressor: ImageCompressor {
        resolve()
    }

    static var notificationHelper: NotificationHelper {
        resolve()
    }

    static var geofenceManager: GeofenceManager {
        resolve()
    }

    static var storageManager: StorageManager {
        resolve()
    }

    static var fcmManager: FcmManager {
        resolve()
    }
}
#endif
