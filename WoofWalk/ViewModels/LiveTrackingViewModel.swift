import Foundation
import SwiftUI
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

// MARK: - ViewModel

/// ViewModel for client-side live tracking of dog walks.
/// Subscribes to a Firestore walk session document and streams real-time updates.
///
/// All data types (LiveWalkSession, LiveWalkStats, LiveWalkStatus, WalkPhotoUpdate,
/// WalkActivityEvent, WalkerInfo, ETACalculation, LiveLocationUpdate, ConnectionStatus)
/// are defined canonically in `Models/WalkActivityEvent.swift`. UI helper extensions
/// live in `ViewModels/LiveTracking+UIExtensions.swift`.
@MainActor
class LiveTrackingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isLoading: Bool = true
    @Published var error: String?
    @Published var walkSession: LiveWalkSession?
    @Published var dogInfo: LiveTrackingDogInfo?
    @Published var connectionStatus: ConnectionStatus = .connected
    @Published var eta: ETACalculation?
    @Published var isMapExpanded: Bool = false

    // MARK: - Event Bus

    enum Event {
        case showMessage(String)
        case navigateToChat(walkerId: String)
        case initiateCall(phoneNumber: String)
        case showEmergencyOptions
    }

    /// One-shot event stream for navigation and alerts
    let eventSubject = PassthroughSubject<Event, Never>()

    // MARK: - Private

    private let walkId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    init(walkId: String) {
        self.walkId = walkId
        guard !walkId.isEmpty else {
            isLoading = false
            error = "No walk ID provided"
            return
        }
        startTracking()
    }

    deinit {
        listener?.remove()
        print("[LiveTrackingVM] Cleaned up listener for walk: \(walkId)")
    }

    // MARK: - Firestore Subscription

    func startTracking() {
        listener?.remove()
        isLoading = true
        error = nil

        listener = db.collection("walk_sessions").document(walkId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("[LiveTrackingVM] Snapshot error: \(error.localizedDescription)")
                    self.isLoading = false
                    self.error = error.localizedDescription
                    return
                }

                guard let data = snapshot?.data(), snapshot?.exists == true else {
                    self.isLoading = false
                    self.error = "Walk session not found or ended"
                    return
                }

                let session = self.parseSession(walkId: snapshot!.documentID, data: data)
                self.walkSession = session

                // Load dog info on first receive
                if self.dogInfo == nil, let firstDogId = session.dogIds.first {
                    self.loadDogInfo(dogId: firstDogId)
                }

                // Determine connection quality
                self.connectionStatus = self.determineConnectionStatus(lastUpdateMs: session.lastUpdateTime)

                // Calculate ETA
                self.eta = self.calculateETA(session: session)

                self.isLoading = false
                self.error = nil

                print("[LiveTrackingVM] Update for walk: \(self.walkId), status: \(session.status.rawValue)")
            }
    }

    // MARK: - Actions

    func sendQuickMessage(_ message: String) {
        guard !walkId.isEmpty else { return }

        let messageData: [String: Any] = [
            "text": message,
            "senderId": Auth.auth().currentUser?.uid ?? "",
            "senderRole": "client",
            "timestamp": FieldValue.serverTimestamp()
        ]

        db.collection("walk_sessions").document(walkId)
            .collection("messages").addDocument(data: messageData) { [weak self] error in
                guard let self else { return }
                if let error {
                    print("[LiveTrackingVM] Failed to send message: \(error.localizedDescription)")
                    self.eventSubject.send(.showMessage("Failed to send message"))
                } else {
                    self.eventSubject.send(.showMessage("Message sent"))
                }
            }
    }

    func onMessageWalkerClicked() {
        guard let walkerId = walkSession?.walkerInfo.id else { return }
        eventSubject.send(.navigateToChat(walkerId: walkerId))
    }

    func onCallWalkerClicked() {
        guard let phone = walkSession?.walkerInfo.phoneNumber else {
            eventSubject.send(.showMessage("Phone number not available"))
            return
        }
        eventSubject.send(.initiateCall(phoneNumber: phone))
    }

    func onEmergencyContactClicked() {
        eventSubject.send(.showEmergencyOptions)
    }

    func toggleMapExpanded() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isMapExpanded.toggle()
        }
    }

    func refresh() {
        startTracking()
    }

    func clearError() {
        error = nil
    }

    // MARK: - Parsing

    private static func parseInt64Timestamp(_ raw: Any?) -> Int64 {
        if let ts = raw as? Timestamp {
            return Int64(ts.dateValue().timeIntervalSince1970 * 1000)
        }
        if let n = raw as? NSNumber {
            return n.int64Value
        }
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    private static func parseLocationUpdate(_ map: [String: Any]) -> LiveLocationUpdate? {
        guard let lat = (map["latitude"] as? NSNumber)?.doubleValue,
              let lng = (map["longitude"] as? NSNumber)?.doubleValue else {
            return nil
        }
        return LiveLocationUpdate(
            latitude: lat,
            longitude: lng,
            timestamp: parseInt64Timestamp(map["timestamp"]),
            accuracy: (map["accuracy"] as? NSNumber)?.floatValue,
            heading: (map["heading"] as? NSNumber)?.floatValue,
            speed: (map["speed"] as? NSNumber)?.floatValue
        )
    }

    private func parseSession(walkId: String, data: [String: Any]) -> LiveWalkSession {
        let statusRaw = data["status"] as? String ?? "CONNECTING"
        let status = LiveWalkStatus(rawValue: statusRaw) ?? .connecting

        // Walker info
        let walkerData = data["walkerInfo"] as? [String: Any] ?? [:]
        let walkerInfo = WalkerInfo(
            id: walkerData["id"] as? String ?? "",
            name: walkerData["name"] as? String ?? "Walker",
            photoUrl: walkerData["photoUrl"] as? String,
            rating: walkerData["rating"] as? Double ?? 0.0,
            phoneNumber: walkerData["phoneNumber"] as? String
        )

        // Current location
        var currentLocation: LiveLocationUpdate?
        if let locData = data["currentLocation"] as? [String: Any] {
            currentLocation = Self.parseLocationUpdate(locData)
        }

        // Home location (stored as latitude/longitude doubles in canonical model)
        var homeLatitude: Double?
        var homeLongitude: Double?
        if let homeData = data["homeLocation"] as? [String: Any] {
            homeLatitude = (homeData["latitude"] as? NSNumber)?.doubleValue
            homeLongitude = (homeData["longitude"] as? NSNumber)?.doubleValue
        }

        // Route points
        let routeData = data["routePoints"] as? [[String: Any]] ?? []
        let routePoints = routeData.compactMap { Self.parseLocationUpdate($0) }

        // Stats
        let statsData = data["stats"] as? [String: Any] ?? [:]
        let stats = LiveWalkStats(
            distanceKm: (statsData["distanceKm"] as? NSNumber)?.doubleValue ?? 0,
            durationSeconds: (statsData["durationSeconds"] as? NSNumber)?.int64Value ?? 0,
            currentPaceMinPerKm: (statsData["currentPaceMinPerKm"] as? NSNumber)?.doubleValue,
            estimatedEndTime: (statsData["estimatedEndTime"] as? NSNumber)?.int64Value,
            averageSpeedKmh: (statsData["averageSpeedKmh"] as? NSNumber)?.doubleValue
        )

        // Activity events
        let eventsData = data["activityEvents"] as? [[String: Any]] ?? []
        let activityEvents = eventsData.map { ev in
            WalkActivityEvent(
                id: ev["id"] as? String ?? UUID().uuidString,
                type: ev["type"] as? String ?? "UNKNOWN",
                timestamp: Self.parseInt64Timestamp(ev["timestamp"]),
                note: ev["note"] as? String,
                photoUrl: ev["photoUrl"] as? String,
                latitude: (ev["latitude"] as? NSNumber)?.doubleValue,
                longitude: (ev["longitude"] as? NSNumber)?.doubleValue
            )
        }

        // Photos
        let photosData = data["photos"] as? [[String: Any]] ?? []
        let photos = photosData.compactMap { ph -> WalkPhotoUpdate? in
            let url = ph["url"] as? String ?? ""
            guard !url.isEmpty else { return nil }
            return WalkPhotoUpdate(
                photoId: ph["photoId"] as? String ?? ph["id"] as? String ?? UUID().uuidString,
                url: url,
                thumbnailUrl: ph["thumbnailUrl"] as? String,
                timestamp: Self.parseInt64Timestamp(ph["timestamp"]),
                latitude: (ph["latitude"] as? NSNumber)?.doubleValue,
                longitude: (ph["longitude"] as? NSNumber)?.doubleValue,
                caption: ph["caption"] as? String
            )
        }

        let dogIds = data["dogIds"] as? [String] ?? []
        let lastUpdate = Self.parseInt64Timestamp(data["lastUpdateTime"])
        let startTime = Self.parseInt64Timestamp(data["startTime"])

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
            lastUpdateTime: lastUpdate,
            homeLatitude: homeLatitude,
            homeLongitude: homeLongitude
        )
    }

    // MARK: - Dog Info

    private func loadDogInfo(dogId: String) {
        db.collection("dogs").document(dogId).getDocument { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                print("[LiveTrackingVM] Failed to load dog info: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data() else { return }
            self.dogInfo = LiveTrackingDogInfo(
                id: dogId,
                name: data["name"] as? String ?? "Unknown",
                breed: data["breed"] as? String,
                photoUrl: data["photoUrl"] as? String
            )
        }
    }

    // MARK: - Connection Status

    private func determineConnectionStatus(lastUpdateMs: Int64) -> ConnectionStatus {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let elapsedMs = nowMs - lastUpdateMs
        if elapsedMs < 30_000 {
            return .connected
        } else if elapsedMs < 120_000 {
            return .delayed
        } else {
            return .lost
        }
    }

    // MARK: - ETA Calculation

    private func calculateETA(session: LiveWalkSession) -> ETACalculation? {
        guard let current = session.currentLocation,
              let home = session.homeLocation else { return nil }

        let currentCL = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let homeCL = CLLocation(latitude: home.latitude, longitude: home.longitude)
        let distanceKm = currentCL.distance(from: homeCL) / 1000.0

        // Use current pace or fallback to 12 min/km (slow walk)
        let paceMinPerKm = session.stats.currentPaceMinPerKm ?? 12.0
        let remainingMinutes = max(1, Int(distanceKm * paceMinPerKm))
        let returnTimeMs = Int64(Date().addingTimeInterval(Double(remainingMinutes) * 60).timeIntervalSince1970 * 1000)

        return ETACalculation(
            estimatedReturnTime: returnTimeMs,
            remainingDistanceKm: distanceKm,
            estimatedRemainingMinutes: remainingMinutes,
            confidenceLevel: session.stats.currentPaceMinPerKm == nil ? 0.5 : 0.7
        )
    }
}

// MARK: - Dog Info (canonical here; not in WalkActivityEvent.swift)

/// Dog info for display in live tracking screen
struct LiveTrackingDogInfo: Equatable {
    let id: String
    let name: String
    let breed: String?
    let photoUrl: String?
}
