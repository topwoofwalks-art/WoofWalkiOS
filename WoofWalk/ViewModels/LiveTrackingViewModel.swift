import Foundation
import SwiftUI
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Data Models

/// Connection quality between client and walker's live updates
enum ConnectionStatus: String {
    case connected
    case delayed
    case lost

    var color: Color {
        switch self {
        case .connected: return Color(hex: 0x4CAF50)
        case .delayed: return Color(hex: 0xFFA000)
        case .lost: return Color(hex: 0xF44336)
        }
    }

    var icon: String {
        switch self {
        case .connected: return "cellularbars"
        case .delayed: return "exclamationmark.triangle.fill"
        case .lost: return "xmark.circle.fill"
        }
    }
}

/// Walk status as reported by the walker
enum LiveWalkStatus: String, Codable {
    case connecting = "CONNECTING"
    case active = "ACTIVE"
    case paused = "PAUSED"
    case ended = "ENDED"
    case error = "ERROR"

    var label: String {
        switch self {
        case .connecting: return "Connecting..."
        case .active: return "Walk in Progress"
        case .paused: return "Paused"
        case .ended: return "Walk Ended"
        case .error: return "Connection Error"
        }
    }

    var color: Color {
        switch self {
        case .connecting: return Color(hex: 0xFFA000)
        case .active: return Color(hex: 0x4CAF50)
        case .paused: return Color(hex: 0xFFA000)
        case .ended: return Color(hex: 0x9E9E9E)
        case .error: return Color(hex: 0xF44336)
        }
    }
}

/// A GPS location update from the walker
struct WalkerLocation: Equatable {
    let latitude: Double
    let longitude: Double
    let heading: Double?
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A point along the walk route
struct RoutePoint: Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Walk statistics streamed in real time
struct LiveWalkStats: Equatable {
    var distanceKm: Double = 0
    var durationSeconds: Int = 0
    var averageSpeedKmh: Double? = nil
    var currentPaceMinPerKm: Double? = nil
}

/// Walker info embedded in session
struct WalkerInfo: Equatable {
    let id: String
    let name: String
    let phoneNumber: String?
    let rating: Double
}

/// A photo update sent by the walker during the walk
struct WalkPhotoUpdate: Identifiable, Equatable {
    let id: String
    let url: String
    let thumbnailUrl: String?
    let caption: String?
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?

    var location: CLLocationCoordinate2D? {
        guard let lat = latitude, let lng = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

/// A real-time activity event during the walk (pee, poo, photo, etc.)
struct WalkActivityEvent: Identifiable, Equatable {
    let id: String
    let type: String
    let note: String?
    let timestamp: Date

    var icon: String {
        switch type.uppercased() {
        case "PEE": return "drop.fill"
        case "POO": return "leaf.fill"
        case "WATER": return "cup.and.saucer.fill"
        case "FEED": return "fork.knife"
        case "PHOTO": return "camera.fill"
        case "NOTE": return "note.text"
        case "CHECK_IN": return "checkmark.circle.fill"
        case "PLAY": return "sportscourt.fill"
        case "INCIDENT": return "exclamationmark.triangle.fill"
        default: return "pawprint.fill"
        }
    }

    var label: String {
        switch type.uppercased() {
        case "PEE": return "Pee break"
        case "POO": return "Poo break"
        case "WATER": return "Had water"
        case "FEED": return "Fed"
        case "PHOTO": return "Photo taken"
        case "NOTE": return "Note"
        case "CHECK_IN": return "Checked in"
        case "PLAY": return "Play time"
        case "INCIDENT": return "Incident"
        default: return type
        }
    }

    var tintColor: Color {
        switch type.uppercased() {
        case "PEE": return Color(hex: 0xFFA000)
        case "POO": return Color(hex: 0x795548)
        case "WATER": return Color(hex: 0x2196F3)
        case "FEED": return Color(hex: 0xFF7043)
        case "PHOTO": return Color(hex: 0x7C4DFF)
        case "NOTE": return Color(hex: 0x607D8B)
        case "CHECK_IN": return Color(hex: 0x4CAF50)
        case "PLAY": return Color(hex: 0x4CAF50)
        case "INCIDENT": return Color(hex: 0xF44336)
        default: return Color(hex: 0x9E9E9E)
        }
    }
}

/// ETA calculation result
struct ETACalculation: Equatable {
    let estimatedReturnTime: Date
    let estimatedRemainingMinutes: Int
    let remainingDistanceKm: Double
}

/// Dog info for display
struct LiveTrackingDogInfo: Equatable {
    let id: String
    let name: String
    let breed: String?
    let photoUrl: String?
}

/// The full live walk session document from Firestore
struct LiveWalkSession: Equatable {
    let id: String
    var status: LiveWalkStatus
    var walkerInfo: WalkerInfo
    var currentLocation: WalkerLocation?
    var homeLocation: CLLocationCoordinate2D?
    var routePoints: [RoutePoint]
    var stats: LiveWalkStats
    var activityEvents: [WalkActivityEvent]
    var photos: [WalkPhotoUpdate]
    var dogIds: [String]
    var lastUpdateTime: Date
}

// MARK: - ViewModel

/// ViewModel for client-side live tracking of dog walks.
/// Subscribes to a Firestore walk session document and streams real-time updates.
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

                let session = self.parseSession(id: snapshot!.documentID, data: data)
                self.walkSession = session

                // Load dog info on first receive
                if self.dogInfo == nil, let firstDogId = session.dogIds.first {
                    self.loadDogInfo(dogId: firstDogId)
                }

                // Determine connection quality
                self.connectionStatus = self.determineConnectionStatus(lastUpdate: session.lastUpdateTime)

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

    private func parseSession(id: String, data: [String: Any]) -> LiveWalkSession {
        let statusRaw = data["status"] as? String ?? "CONNECTING"
        let status = LiveWalkStatus(rawValue: statusRaw) ?? .connecting

        // Walker info
        let walkerData = data["walkerInfo"] as? [String: Any] ?? [:]
        let walkerInfo = WalkerInfo(
            id: walkerData["id"] as? String ?? "",
            name: walkerData["name"] as? String ?? "Walker",
            phoneNumber: walkerData["phoneNumber"] as? String,
            rating: walkerData["rating"] as? Double ?? 0.0
        )

        // Current location
        var currentLocation: WalkerLocation?
        if let locData = data["currentLocation"] as? [String: Any] {
            currentLocation = WalkerLocation(
                latitude: locData["latitude"] as? Double ?? 0,
                longitude: locData["longitude"] as? Double ?? 0,
                heading: locData["heading"] as? Double,
                timestamp: (locData["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        }

        // Home location
        var homeLocation: CLLocationCoordinate2D?
        if let homeData = data["homeLocation"] as? [String: Any] {
            let lat = homeData["latitude"] as? Double ?? 0
            let lng = homeData["longitude"] as? Double ?? 0
            homeLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        // Route points
        let routeData = data["routePoints"] as? [[String: Any]] ?? []
        let routePoints = routeData.map { pt in
            RoutePoint(
                latitude: pt["latitude"] as? Double ?? 0,
                longitude: pt["longitude"] as? Double ?? 0
            )
        }

        // Stats
        let statsData = data["stats"] as? [String: Any] ?? [:]
        let stats = LiveWalkStats(
            distanceKm: statsData["distanceKm"] as? Double ?? 0,
            durationSeconds: statsData["durationSeconds"] as? Int ?? 0,
            averageSpeedKmh: statsData["averageSpeedKmh"] as? Double,
            currentPaceMinPerKm: statsData["currentPaceMinPerKm"] as? Double
        )

        // Activity events
        let eventsData = data["activityEvents"] as? [[String: Any]] ?? []
        let activityEvents = eventsData.map { ev in
            WalkActivityEvent(
                id: ev["id"] as? String ?? UUID().uuidString,
                type: ev["type"] as? String ?? "UNKNOWN",
                note: ev["note"] as? String,
                timestamp: (ev["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        }

        // Photos
        let photosData = data["photos"] as? [[String: Any]] ?? []
        let photos = photosData.map { ph in
            WalkPhotoUpdate(
                id: ph["id"] as? String ?? UUID().uuidString,
                url: ph["url"] as? String ?? "",
                thumbnailUrl: ph["thumbnailUrl"] as? String,
                caption: ph["caption"] as? String,
                timestamp: (ph["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                latitude: ph["latitude"] as? Double,
                longitude: ph["longitude"] as? Double
            )
        }

        let dogIds = data["dogIds"] as? [String] ?? []
        let lastUpdate = (data["lastUpdateTime"] as? Timestamp)?.dateValue() ?? Date()

        return LiveWalkSession(
            id: id,
            status: status,
            walkerInfo: walkerInfo,
            currentLocation: currentLocation,
            homeLocation: homeLocation,
            routePoints: routePoints,
            stats: stats,
            activityEvents: activityEvents,
            photos: photos,
            dogIds: dogIds,
            lastUpdateTime: lastUpdate
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

    private func determineConnectionStatus(lastUpdate: Date) -> ConnectionStatus {
        let elapsed = Date().timeIntervalSince(lastUpdate)
        if elapsed < 30 {
            return .connected
        } else if elapsed < 120 {
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
        let returnTime = Date().addingTimeInterval(Double(remainingMinutes) * 60)

        return ETACalculation(
            estimatedReturnTime: returnTime,
            estimatedRemainingMinutes: remainingMinutes,
            remainingDistanceKm: distanceKm
        )
    }
}
