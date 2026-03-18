// This file is excluded from compilation because it references types
// that don't exist in the actual codebase yet.
#if false
import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

class UserDataStore: ObservableObject {
    static let shared = UserDataStore()
    @Published var viewport: Viewport?

    init() {}
}

struct Viewport: Codable {
    let centerLat: Double
    let centerLng: Double
    let zoomLevel: Double
}

class ImageCompressor {
    func compress(image: UIImage, maxSizeKB: Int) async throws -> Data {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageCompressor", code: -1)
        }
        return data
    }
}

class NotificationHelper {
    func requestAuthorization() async throws -> Bool {
        return true
    }

    func scheduleNotification(title: String, body: String, after: TimeInterval) {
    }
}

class StubGeofenceManager {
    private let locationService: LocationService
    private let poiRepository: PoiRepository

    init(locationService: LocationService, poiRepository: PoiRepository) {
        self.locationService = locationService
        self.poiRepository = poiRepository
    }

    func setupGeofences(for pois: [Poi]) {
    }

    func removeAllGeofences() {
    }
}

class StorageManager {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    func uploadImage(_ data: Data, path: String) async throws -> URL {
        let ref = storage.reference().child(path)
        _ = try await ref.putDataAsync(data)
        return try await ref.downloadURL()
    }

    func deleteFile(at path: String) async throws {
        let ref = storage.reference().child(path)
        try await ref.delete()
    }
}

class FcmManager {
    private let firestore: Firestore
    private let auth: Auth

    init(firestore: Firestore, auth: Auth) {
        self.firestore = firestore
        self.auth = auth
    }

    func registerToken(_ token: String) async throws {
        guard let userId = auth.currentUser?.uid else { return }
        try await firestore.collection("users").document(userId)
            .setData(["fcmToken": token], merge: true)
    }

    func removeToken() async throws {
        guard let userId = auth.currentUser?.uid else { return }
        try await firestore.collection("users").document(userId)
            .updateData(["fcmToken": FieldValue.delete()])
    }
}

class StubDogRepository: ObservableObject {
    private let dogDao: DogDao
    private let firestore: Firestore
    private let auth: Auth
    private let storage: Storage

    @Published var dogs: [Dog] = []

    init(dogDao: DogDao, firestore: Firestore, auth: Auth, storage: Storage) {
        self.dogDao = dogDao
        self.firestore = firestore
        self.auth = auth
        self.storage = storage
    }

    func fetchDogs() async throws -> [Dog] {
        return try await dogDao.getAllDogs()
    }

    func addDog(_ dog: Dog) async throws {
        try await dogDao.insert(dog)
        guard let userId = auth.currentUser?.uid else { return }
        try await firestore.collection("users").document(userId)
            .collection("dogs").document(dog.id).setData(dog.toDictionary())
    }

    func updateDog(_ dog: Dog) async throws {
        try await dogDao.update(dog)
        guard let userId = auth.currentUser?.uid else { return }
        try await firestore.collection("users").document(userId)
            .collection("dogs").document(dog.id).updateData(dog.toDictionary())
    }

    func deleteDog(_ dogId: String) async throws {
        try await dogDao.delete(dogId)
        guard let userId = auth.currentUser?.uid else { return }
        try await firestore.collection("users").document(userId)
            .collection("dogs").document(dogId).delete()
    }
}

class StubWalkRepository: ObservableObject {
    private let walkDao: WalkDao
    private let firestore: Firestore
    private let auth: Auth

    @Published var walks: [Walk] = []

    init(walkDao: WalkDao, firestore: Firestore, auth: Auth) {
        self.walkDao = walkDao
        self.firestore = firestore
        self.auth = auth
    }

    func fetchWalks(limit: Int = 20) async throws -> [Walk] {
        return try await walkDao.getRecentWalks(limit: limit)
    }

    func saveWalk(_ walk: Walk) async throws {
        try await walkDao.insert(walk)
        guard let userId = auth.currentUser?.uid else { return }
        try await firestore.collection("users").document(userId)
            .collection("walks").document(walk.id).setData(walk.toDictionary())
    }
}

class StubWalkSessionRepository {
    private let walkSessionDao: WalkSessionDao
    private let firestore: Firestore
    private let auth: Auth

    init(walkSessionDao: WalkSessionDao, firestore: Firestore, auth: Auth) {
        self.walkSessionDao = walkSessionDao
        self.firestore = firestore
        self.auth = auth
    }

    func createSession(_ session: WalkSession) async throws {
        try await walkSessionDao.insert(session)
    }

    func updateSession(_ session: WalkSession) async throws {
        try await walkSessionDao.update(session)
    }

    func getActiveSession() async throws -> WalkSession? {
        return try await walkSessionDao.getActiveSession()
    }
}

class PoiCacheRepository {
    private let cachedPoiDao: CachedPoiDao
    private let overpassService: OverpassService

    init(cachedPoiDao: CachedPoiDao, overpassService: OverpassService) {
        self.cachedPoiDao = cachedPoiDao
        self.overpassService = overpassService
    }

    func getCachedPois(bounds: GeoBounds) async throws -> [Poi] {
        return try await cachedPoiDao.getPoisInBounds(bounds: bounds)
    }

    func cachePois(_ pois: [Poi]) async throws {
        for poi in pois {
            try await cachedPoiDao.insert(poi)
        }
    }
}

class RouteRepository {
    private let osrmService: OsrmService
    private let directionsService: DirectionsService

    init(osrmService: OsrmService, directionsService: DirectionsService) {
        self.osrmService = osrmService
        self.directionsService = directionsService
    }

    func getRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> Route {
        return try await osrmService.getRoute(from: from, to: to)
    }
}

class DirectionsRepository {
    private let directionsService: DirectionsService

    init(directionsService: DirectionsService) {
        self.directionsService = directionsService
    }

    func getDirections(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> DirectionsResult {
        return try await directionsService.getDirections(origin: from, destination: to)
    }
}

class StubPooBagDropRepository: ObservableObject {
    private let pooBagDropDao: PooBagDropDao
    private let firestore: Firestore
    private let auth: Auth

    @Published var activeBagDrops: [PooBagDrop] = []

    init(pooBagDropDao: PooBagDropDao, firestore: Firestore, auth: Auth) {
        self.pooBagDropDao = pooBagDropDao
        self.firestore = firestore
        self.auth = auth
    }

    func getActiveBagDrops() -> [PooBagDrop] {
        return activeBagDrops
    }

    func addBagDrop(_ drop: PooBagDrop) async throws {
        try await pooBagDropDao.insert(drop)
        try await firestore.collection("pooBagDrops").document(drop.id).setData(drop.toDictionary())
    }
}

class PublicDogRepository {
    private let firestore: Firestore
    private let auth: Auth

    init(firestore: Firestore, auth: Auth) {
        self.firestore = firestore
        self.auth = auth
    }

    func getNearbyDogs(location: CLLocationCoordinate2D, radius: Double) async throws -> [PublicDog] {
        return []
    }
}

class LostDogRepository {
    private let firestore: Firestore
    private let auth: Auth
    private let storage: Storage

    init(firestore: Firestore, auth: Auth, storage: Storage) {
        self.firestore = firestore
        self.auth = auth
        self.storage = storage
    }

    func reportLostDog(_ dog: LostDog) async throws {
        try await firestore.collection("lostDogs").document(dog.id).setData(dog.toDictionary())
    }

    func getNearbyLostDogs(location: CLLocationCoordinate2D, radius: Double) async throws -> [LostDog] {
        return []
    }
}

class FriendRepository {
    private let firestore: Firestore
    private let auth: Auth

    init(firestore: Firestore, auth: Auth) {
        self.firestore = firestore
        self.auth = auth
    }

    func getFriends() async throws -> [User] {
        return []
    }

    func sendFriendRequest(toUserId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else { return }
        let data: [String: Any] = [
            "userId1": currentUserId,
            "userId2": toUserId,
            "status": "PENDING",
            "requestedBy": currentUserId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await firestore.collection("friendships").addDocument(data: data)
    }
}

class ChatRepository {
    private let firestore: Firestore
    private let auth: Auth

    init(firestore: Firestore, auth: Auth) {
        self.firestore = firestore
        self.auth = auth
    }

    func getChats() async throws -> [Chat] {
        return []
    }

    func sendMessage(chatId: String, text: String) async throws {
        guard let userId = auth.currentUser?.uid else { return }
        try await firestore.collection("chats").document(chatId)
            .collection("messages").addDocument(data: [
                "senderId": userId,
                "text": text,
                "timestamp": FieldValue.serverTimestamp()
            ])
    }
}

class FeedRepository {
    private let firestore: Firestore
    private let auth: Auth
    private let storage: Storage

    init(firestore: Firestore, auth: Auth, storage: Storage) {
        self.firestore = firestore
        self.auth = auth
        self.storage = storage
    }

    func getFeed(limit: Int = 20) async throws -> [FeedPost] {
        return []
    }

    func createPost(_ post: FeedPost) async throws {
        try await firestore.collection("posts").document(post.id).setData(post.toDictionary())
    }
}

class EventRepository {
    private let firestore: Firestore
    private let auth: Auth

    init(firestore: Firestore, auth: Auth) {
        self.firestore = firestore
        self.auth = auth
    }

    func getEvents(near location: CLLocationCoordinate2D, radius: Double) async throws -> [Event] {
        return []
    }

    func createEvent(_ event: Event) async throws {
        try await firestore.collection("events").document(event.id).setData(event.toDictionary())
    }
}
#endif
