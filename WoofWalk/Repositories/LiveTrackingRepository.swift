import Foundation
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

/// Repository for live walk tracking functionality.
/// Allows clients to monitor their dog's walk in real-time.
class LiveTrackingRepository {
    static let shared = LiveTrackingRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    // Collection names
    private static let collectionWalkSessions = "walk_sessions"
    private static let collectionMessages = "messages"
    private static let collectionRequests = "requests"

    // Connection status thresholds in milliseconds
    private static let connectedThresholdMs: Int64 = 30_000
    private static let delayedThresholdMs: Int64 = 120_000

    // Default walking pace (min per km) for ETA calculations
    private static let defaultPaceMinPerKm: Double = 12.0

    // Earth radius in meters for haversine calculation
    private static let earthRadiusMeters: Double = 6_371_000.0

    private init() {}

    // MARK: - Subscribe to Walk Session

    /// Subscribe to real-time updates for a walk session.
    /// Returns a publisher that emits LiveWalkSession updates.
    func subscribeToWalkSession(walkId: String) -> AnyPublisher<LiveWalkSession?, Never> {
        let subject = PassthroughSubject<LiveWalkSession?, Never>()

        let listener = db.collection(Self.collectionWalkSessions)
            .document(walkId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to walk session \(walkId): \(error.localizedDescription)")
                    subject.send(nil)
                    return
                }

                guard let snapshot = snapshot, snapshot.exists,
                      let data = snapshot.data() else {
                    print("Walk session \(walkId) not found")
                    subject.send(nil)
                    return
                }

                do {
                    let session = try Self.parseWalkSession(walkId: walkId, data: data)
                    subject.send(session)
                } catch {
                    print("Error parsing walk session \(walkId): \(error.localizedDescription)")
                    subject.send(nil)
                }
            }

        return subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }

    // MARK: - Get Current Walker Location

    /// Get the current walker location for a walk.
    func getCurrentWalkerLocation(walkId: String) async throws -> LiveLocationUpdate? {
        let snapshot = try await db.collection(Self.collectionWalkSessions)
            .document(walkId)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data(),
              let locationMap = data["currentLocation"] as? [String: Any] else {
            return nil
        }

        return Self.parseLiveLocationUpdate(locationMap)
    }

    // MARK: - Get Walk Route Polyline

    /// Get the route polyline (all tracked points) for a walk.
    func getWalkRoutePolyline(walkId: String) async throws -> [LiveLocationUpdate] {
        let snapshot = try await db.collection(Self.collectionWalkSessions)
            .document(walkId)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data(),
              let routePoints = data["routePoints"] as? [[String: Any]] else {
            return []
        }

        return routePoints.compactMap { Self.parseLiveLocationUpdate($0) }
    }

    // MARK: - Get Live Walk Stats

    /// Get live walk statistics.
    func getLiveWalkStats(walkId: String) async throws -> LiveWalkStats? {
        let snapshot = try await db.collection(Self.collectionWalkSessions)
            .document(walkId)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data(),
              let statsMap = data["stats"] as? [String: Any] else {
            return nil
        }

        return Self.parseLiveWalkStats(statsMap)
    }

    // MARK: - Get Walk Photos

    /// Get photos taken during the walk.
    func getWalkPhotos(walkId: String) async throws -> [WalkPhotoUpdate] {
        let snapshot = try await db.collection(Self.collectionWalkSessions)
            .document(walkId)
            .getDocument()

        guard snapshot.exists, let data = snapshot.data(),
              let photos = data["photos"] as? [[String: Any]] else {
            return []
        }

        return photos.compactMap { Self.parseWalkPhotoUpdate($0) }
    }

    // MARK: - Send Message to Walker

    /// Send a message to the walker during the walk.
    func sendMessageToWalker(walkId: String, message: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw LiveTrackingError.userNotAuthenticated
        }

        let messageId = UUID().uuidString
        let messageData: [String: Any] = [
            "messageId": messageId,
            "fromClientToWalker": true,
            "content": message,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "isRead": false
        ]

        try await db.collection(Self.collectionWalkSessions)
            .document(walkId)
            .collection(Self.collectionMessages)
            .document(messageId)
            .setData(messageData)

        print("Message sent to walker for walk \(walkId)")
    }

    // MARK: - Request End Walk

    /// Request the walker to end the walk early.
    func requestEndWalk(walkId: String, reason: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw LiveTrackingError.userNotAuthenticated
        }

        let requestData: [String: Any] = [
            "type": "END_WALK_REQUEST",
            "requestedBy": userId,
            "reason": reason,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]

        try await db.collection(Self.collectionWalkSessions)
            .document(walkId)
            .collection(Self.collectionRequests)
            .addDocument(data: requestData)

        print("End walk request sent for walk \(walkId)")
    }

    // MARK: - Calculate ETA

    /// Calculate estimated time of arrival back home.
    func calculateETA(
        currentLocation: CLLocationCoordinate2D,
        homeLocation: CLLocationCoordinate2D,
        averagePaceMinPerKm: Double?
    ) -> ETACalculation {
        let distanceKm = Self.haversineDistance(
            lat1: currentLocation.latitude,
            lng1: currentLocation.longitude,
            lat2: homeLocation.latitude,
            lng2: homeLocation.longitude
        ) / 1000.0

        let pace = averagePaceMinPerKm ?? Self.defaultPaceMinPerKm
        let estimatedMinutes = Int(pace * distanceKm)
        let estimatedReturnTime = Int64(Date().timeIntervalSince1970 * 1000) + Int64(estimatedMinutes * 60_000)

        let confidenceLevel: Double
        if averagePaceMinPerKm == nil {
            confidenceLevel = 0.5
        } else if distanceKm < 2.0 {
            confidenceLevel = 0.9
        } else {
            confidenceLevel = 0.7
        }

        return ETACalculation(
            estimatedReturnTime: estimatedReturnTime,
            remainingDistanceKm: distanceKm,
            estimatedRemainingMinutes: estimatedMinutes,
            confidenceLevel: confidenceLevel
        )
    }

    // MARK: - Determine Connection Status

    /// Determine connection status based on last update timestamp.
    func determineConnectionStatus(lastUpdateTimestamp: Int64) -> ConnectionStatus {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let timeSinceLastUpdate = now - lastUpdateTimestamp

        if timeSinceLastUpdate < Self.connectedThresholdMs {
            return .connected
        } else if timeSinceLastUpdate < Self.delayedThresholdMs {
            return .delayed
        } else {
            return .lost
        }
    }

    // MARK: - Private Helpers

    /// Calculate haversine distance between two points in meters.
    private static func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLng = (lng2 - lng1) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }

    /// Parse a complete walk session from Firestore data.
    private static func parseWalkSession(walkId: String, data: [String: Any]) throws -> LiveWalkSession? {
        let dogIds = (data["dogIds"] as? [String]) ?? []

        guard let walkerInfoMap = data["walkerInfo"] as? [String: Any],
              let walkerInfo = parseWalkerInfo(walkerInfoMap) else {
            return nil
        }

        let currentLocation = (data["currentLocation"] as? [String: Any]).flatMap { parseLiveLocationUpdate($0) }

        let routePoints = (data["routePoints"] as? [[String: Any]])?.compactMap { parseLiveLocationUpdate($0) } ?? []

        let statsMap = data["stats"] as? [String: Any]
        let stats = statsMap.map { parseLiveWalkStats($0) } ?? LiveWalkStats()

        let photos = (data["photos"] as? [[String: Any]])?.compactMap { parseWalkPhotoUpdate($0) } ?? []

        let activityEvents = (data["activityEvents"] as? [[String: Any]])?.compactMap { parseActivityEvent($0) } ?? []

        let statusString = data["status"] as? String ?? "ACTIVE"
        let status = LiveWalkStatus(rawValue: statusString) ?? .active

        let startTime = (data["startTime"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
        let lastUpdateTime = (data["lastUpdateTime"] as? NSNumber)?.int64Value ?? startTime

        let homeLocationMap = data["homeLocation"] as? [String: Any]
        let homeLat = (homeLocationMap?["latitude"] as? NSNumber)?.doubleValue
        let homeLng = (homeLocationMap?["longitude"] as? NSNumber)?.doubleValue

        return LiveWalkSession(
            walkId: walkId,
            bookingId: data["bookingId"] as? String,
            dogIds: dogIds,
            walkerInfo: walkerInfo,
            currentLocation: currentLocation,
            routePoints: routePoints,
            stats: stats,
            photos: photos,
            activityEvents: activityEvents,
            status: status,
            startTime: startTime,
            lastUpdateTime: lastUpdateTime,
            homeLatitude: homeLat,
            homeLongitude: homeLng
        )
    }

    /// Parse location update from Firestore map.
    private static func parseLiveLocationUpdate(_ map: [String: Any]) -> LiveLocationUpdate? {
        guard let lat = (map["latitude"] as? NSNumber)?.doubleValue,
              let lng = (map["longitude"] as? NSNumber)?.doubleValue else {
            return nil
        }

        let timestamp = (map["timestamp"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
        let accuracy = (map["accuracy"] as? NSNumber)?.floatValue
        let heading = (map["heading"] as? NSNumber)?.floatValue
        let speed = (map["speed"] as? NSNumber)?.floatValue

        return LiveLocationUpdate(
            latitude: lat,
            longitude: lng,
            timestamp: timestamp,
            accuracy: accuracy,
            heading: heading,
            speed: speed
        )
    }

    /// Parse live walk stats from Firestore map.
    private static func parseLiveWalkStats(_ map: [String: Any]) -> LiveWalkStats {
        return LiveWalkStats(
            distanceKm: (map["distanceKm"] as? NSNumber)?.doubleValue ?? 0.0,
            durationSeconds: (map["durationSeconds"] as? NSNumber)?.int64Value ?? 0,
            currentPaceMinPerKm: (map["currentPaceMinPerKm"] as? NSNumber)?.doubleValue,
            estimatedEndTime: (map["estimatedEndTime"] as? NSNumber)?.int64Value,
            averageSpeedKmh: (map["averageSpeedKmh"] as? NSNumber)?.doubleValue
        )
    }

    /// Parse walk photo update from Firestore map.
    private static func parseWalkPhotoUpdate(_ map: [String: Any]) -> WalkPhotoUpdate? {
        guard let url = map["url"] as? String else { return nil }

        let photoId = map["photoId"] as? String ?? ""
        let timestamp = (map["timestamp"] as? NSNumber)?.int64Value ?? 0
        let caption = map["caption"] as? String
        let thumbnailUrl = map["thumbnailUrl"] as? String

        let locationMap = map["location"] as? [String: Any]
        let lat = (locationMap?["latitude"] as? NSNumber)?.doubleValue
        let lng = (locationMap?["longitude"] as? NSNumber)?.doubleValue

        return WalkPhotoUpdate(
            photoId: photoId,
            url: url,
            thumbnailUrl: thumbnailUrl,
            timestamp: timestamp,
            latitude: lat,
            longitude: lng,
            caption: caption
        )
    }

    /// Parse activity event from Firestore map.
    private static func parseActivityEvent(_ map: [String: Any]) -> WalkActivityEvent? {
        guard let id = map["id"] as? String,
              let type = map["type"] as? String else {
            return nil
        }

        let timestamp = (map["timestamp"] as? NSNumber)?.int64Value ?? 0
        let note = map["note"] as? String
        let photoUrl = map["photoUrl"] as? String
        let lat = (map["latitude"] as? NSNumber)?.doubleValue
        let lng = (map["longitude"] as? NSNumber)?.doubleValue

        return WalkActivityEvent(
            id: id,
            type: type,
            timestamp: timestamp,
            note: note,
            photoUrl: photoUrl,
            latitude: lat,
            longitude: lng
        )
    }

    /// Parse walker info from Firestore map.
    private static func parseWalkerInfo(_ map: [String: Any]) -> WalkerInfo? {
        guard let id = map["id"] as? String,
              let name = map["name"] as? String else {
            return nil
        }

        let photoUrl = map["photoUrl"] as? String
        let rating = (map["rating"] as? NSNumber)?.doubleValue ?? 0.0
        let phoneNumber = map["phoneNumber"] as? String

        return WalkerInfo(
            id: id,
            name: name,
            photoUrl: photoUrl,
            rating: rating,
            phoneNumber: phoneNumber
        )
    }
}

// MARK: - Live Tracking Error

enum LiveTrackingError: LocalizedError {
    case userNotAuthenticated
    case sessionNotFound
    case parseError

    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .sessionNotFound:
            return "Walk session not found"
        case .parseError:
            return "Failed to parse walk session data"
        }
    }
}
