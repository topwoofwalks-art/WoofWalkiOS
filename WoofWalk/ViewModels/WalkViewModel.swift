import Foundation
import Combine
import CoreLocation
import SwiftUI

// MARK: - Tracking State
enum TrackingState: Equatable {
    case idle
    case active(sessionId: String)
    case summary(session: WalkSession)
}

// MARK: - Walk Session Model
struct WalkSession: Identifiable, Codable, Equatable {
    let id: String
    let sessionId: String
    let startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var durationSec: Int
    var avgPaceSecPerKm: Double?
    var notes: String?

    var isActive: Bool {
        endedAt == nil
    }
}

// MARK: - Walk Track Point Model
struct WalkTrackPoint: Identifiable, Codable, Equatable {
    let id: String
    let sessionId: String
    let lat: Double
    let lng: Double
    let accMeters: Float?
    let timestamp: Date
}

// MARK: - Walk Statistics
struct WalkStatistics {
    var currentSpeed: Double = 0.0 // km/h
    var averageSpeed: Double = 0.0 // km/h
    var currentPace: Double = 0.0 // min/km
    var averagePace: Double = 0.0 // min/km
    var distanceKm: Double = 0.0
    var elapsedTime: TimeInterval = 0.0
    var eta: TimeInterval? = nil
}

// MARK: - Walk View Model
@MainActor
class WalkViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var trackingState: TrackingState = .idle
    @Published private(set) var currentSession: WalkSession?
    @Published private(set) var trackPoints: [WalkTrackPoint] = []
    @Published private(set) var selectedDogIds: Set<String> = []
    @Published private(set) var statistics: WalkStatistics = WalkStatistics()
    @Published private(set) var isWalkPublic: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var locationUpdateTimer: Timer?
    private var statisticsTimer: Timer?
    private var lastLocationUpdate: Date?
    private var currentWalkId: String?
    private var currentWalkDogs: [Dog] = []

    // Dependencies (to be injected)
    private let walkRepository: WalkRepository
    private let dogRepository: WalkDogRepository
    private let locationManager: WalkLocationManager

    // MARK: - Initialization
    init(
        walkRepository: WalkRepository,
        dogRepository: WalkDogRepository,
        locationManager: WalkLocationManager
    ) {
        self.walkRepository = walkRepository
        self.dogRepository = dogRepository
        self.locationManager = locationManager

        setupSubscriptions()
        restoreActiveSession()
    }

    // MARK: - Setup
    private func setupSubscriptions() {
        // Subscribe to location updates
        locationManager.locationPublisher
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)

        // Monitor active session changes
        $currentSession
            .sink { [weak self] session in
                self?.updateStatistics()
            }
            .store(in: &cancellables)
    }

    private func restoreActiveSession() {
        Task {
            do {
                if let activeSession = try await walkRepository.getActiveSession() {
                    currentSession = activeSession
                    trackingState = .active(sessionId: activeSession.sessionId)
                    trackPoints = try await walkRepository.getTrackPoints(sessionId: activeSession.sessionId)
                    startStatisticsTimer()
                    print("Restored active session: \(activeSession.sessionId)")
                }
            } catch {
                print("Error restoring active session: \(error)")
            }
        }
    }

    // MARK: - Dog Selection
    func toggleDogSelection(dogId: String) {
        if selectedDogIds.contains(dogId) {
            selectedDogIds.remove(dogId)
            print("Dog deselected: \(dogId)")
        } else {
            selectedDogIds.insert(dogId)
            print("Dog selected: \(dogId)")
        }
    }

    func clearDogSelection() {
        selectedDogIds.removeAll()
    }

    // MARK: - Walk Control
    func startWalk(showPublicly: Bool = false) async throws {
        guard !selectedDogIds.isEmpty else {
            throw WalkError.noDogSelected
        }

        guard case .idle = trackingState else {
            throw WalkError.walkAlreadyInProgress
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let sessionId = try await walkRepository.startSession(dogIds: Array(selectedDogIds))

            currentWalkId = sessionId
            isWalkPublic = showPublicly
            trackingState = .active(sessionId: sessionId)

            // Fetch the newly created session
            currentSession = try await walkRepository.getSession(sessionId: sessionId)

            // Get selected dogs
            currentWalkDogs = try await dogRepository.getDogs(ids: Array(selectedDogIds))

            // Start location tracking with the same context the crash-
            // recovery sheet looks for — without dogIds + mode the
            // post-crash resume flow showed "0 dogs tagged". Mirrors
            // Android's `WalkTrackingService.startTracking(sessionId, dogIds, mode)`.
            // Default mode is `.walk`; switching to e.g. "runWith" or
            // "trainingSession" is a follow-up once the VM tracks mode.
            locationManager.startTracking(
                dogIds: Array(selectedDogIds),
                mode: .walk
            )

            // Start statistics timer
            startStatisticsTimer()

            print("Walk started: \(sessionId) with \(selectedDogIds.count) dog(s), public: \(showPublicly)")

            // Make dogs public if requested
            if showPublicly, let firstPoint = trackPoints.first {
                try await makeDogsPublic(firstPoint: firstPoint)
            }
        } catch {
            print("Failed to start walk: \(error)")
            throw error
        }
    }

    func pauseWalk() {
        guard case .active = trackingState else { return }

        locationManager.pauseTracking()
        print("Walk paused")
    }

    func resumeWalk() {
        guard case .active = trackingState else { return }

        locationManager.resumeTracking()
        print("Walk resumed")
    }

    func stopWalk() async throws {
        guard case .active(let sessionId) = trackingState else {
            throw WalkError.noActiveWalk
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Stop location tracking
            locationManager.stopTracking()

            // Stop statistics timer
            stopStatisticsTimer()

            // Remove from public if needed
            if isWalkPublic, let walkId = currentWalkId {
                try await removeDogsFromPublic(walkId: walkId)
            }

            // Stop the session in repository
            try await walkRepository.stopSession(sessionId: sessionId)

            // Fetch final session data
            if let stoppedSession = try await walkRepository.getSession(sessionId: sessionId) {
                trackingState = .summary(session: stoppedSession)
            } else {
                trackingState = .idle
            }

            // Reset state
            selectedDogIds.removeAll()
            isWalkPublic = false
            currentWalkId = nil
            currentWalkDogs.removeAll()

            print("Walk stopped: \(sessionId)")
        } catch {
            print("Failed to stop walk: \(error)")
            throw error
        }
    }

    func dismissSummary() {
        trackingState = .idle
        currentSession = nil
        trackPoints.removeAll()
        statistics = WalkStatistics()
        print("Summary dismissed, returning to idle state")
    }

    // MARK: - Location Updates
    private func handleLocationUpdate(_ location: CLLocation) {
        Task {
            guard case .active(let sessionId) = trackingState else { return }

            do {
                try await onLocationUpdate(
                    sessionId: sessionId,
                    lat: location.coordinate.latitude,
                    lng: location.coordinate.longitude,
                    accMeters: Float(location.horizontalAccuracy)
                )
            } catch {
                print("Error handling location update: \(error)")
            }
        }
    }

    private func onLocationUpdate(sessionId: String, lat: Double, lng: Double, accMeters: Float?) async throws {
        guard var session = currentSession, session.isActive else {
            print("No active session for location update")
            return
        }

        // Add track point
        let point = try await walkRepository.appendTrackPoint(
            sessionId: sessionId,
            lat: lat,
            lng: lng,
            accMeters: accMeters
        )

        trackPoints.append(point)
        lastLocationUpdate = Date()

        // Update public location if needed
        if isWalkPublic {
            for dog in currentWalkDogs {
                try? await updatePublicDogLocation(dogId: dog.id, lat: lat, lng: lng)
            }
        }

        print("Track point added to \(sessionId): (\(lat), \(lng))")
    }

    // MARK: - Statistics Calculation
    private func startStatisticsTimer() {
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let vm = self else { return }
            Task { @MainActor in
                vm.updateStatistics()
            }
        }
    }

    private func stopStatisticsTimer() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
    }

    private func updateStatistics() {
        guard let session = currentSession else {
            statistics = WalkStatistics()
            return
        }

        let now = Date()
        let elapsed = session.isActive ? now.timeIntervalSince(session.startedAt) : TimeInterval(session.durationSec)
        let distanceMeters = session.distanceMeters
        let distanceKm = distanceMeters / 1000.0

        // Current speed (based on recent track points)
        var currentSpeed = 0.0
        if trackPoints.count >= 2, let lastUpdate = lastLocationUpdate {
            let recentPoints = trackPoints.suffix(5)
            let recentDistance = computePolylineDistance(points: Array(recentPoints))
            let timeDiff = now.timeIntervalSince(lastUpdate)
            if timeDiff > 0 {
                currentSpeed = (recentDistance / 1000.0) / (timeDiff / 3600.0) // km/h
            }
        }

        // Average speed
        let averageSpeed = elapsed > 0 ? (distanceKm / (elapsed / 3600.0)) : 0.0

        // Current pace (min/km)
        let currentPace = currentSpeed > 0 ? 60.0 / currentSpeed : 0.0

        // Average pace (min/km)
        let averagePace = averageSpeed > 0 ? 60.0 / averageSpeed : 0.0

        statistics = WalkStatistics(
            currentSpeed: currentSpeed,
            averageSpeed: averageSpeed,
            currentPace: currentPace,
            averagePace: averagePace,
            distanceKm: distanceKm,
            elapsedTime: elapsed,
            eta: nil
        )
    }

    // MARK: - Distance Calculation
    private func computePolylineDistance(points: [WalkTrackPoint]) -> Double {
        guard points.count >= 2 else { return 0.0 }

        var totalDistance = 0.0
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]
            totalDistance += haversineDistance(
                lat1: p1.lat,
                lng1: p1.lng,
                lat2: p2.lat,
                lng2: p2.lng
            )
        }

        return totalDistance
    }

    private func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLng = (lng2 - lng1) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    // MARK: - Public Dogs
    private func makeDogsPublic(firstPoint: WalkTrackPoint) async throws {
        guard let walkId = currentWalkId else { return }

        // TODO: Implement public dog repository integration
        print("Making dogs public for walk \(walkId)")
    }

    private func removeDogsFromPublic(walkId: String) async throws {
        // TODO: Implement public dog repository integration
        print("Removing dogs from public for walk \(walkId)")
    }

    private func updatePublicDogLocation(dogId: String, lat: Double, lng: Double) async throws {
        // TODO: Implement public dog repository integration
        print("Updating public location for dog \(dogId)")
    }

    // MARK: - Photos & POI
    func addPhotoToWalk(image: UIImage) async throws {
        guard case .active(let sessionId) = trackingState else {
            throw WalkError.noActiveWalk
        }

        // TODO: Implement photo upload
        print("Adding photo to walk \(sessionId)")
    }

    func markWasteDisposal(lat: Double, lng: Double) async throws {
        guard case .active(let sessionId) = trackingState else {
            throw WalkError.noActiveWalk
        }

        let geohash = Geohash.encode(latitude: lat, longitude: lng, precision: 9)

        let poi = POI(
            type: PoiType.bin.rawValue,
            title: "Waste Bin",
            desc: "Waste disposal bin added during walk \(sessionId)",
            lat: lat,
            lng: lng,
            geohash: geohash,
            status: PoiStatus.active.rawValue
        )

        let docId = try await PoiRepository.shared.createPoi(poi)
        print("Waste disposal POI created: \(docId) at (\(lat), \(lng))")
    }

    func markPOI(name: String, lat: Double, lng: Double) async throws {
        guard case .active(let sessionId) = trackingState else {
            throw WalkError.noActiveWalk
        }

        let geohash = Geohash.encode(latitude: lat, longitude: lng, precision: 9)

        let poi = POI(
            type: PoiType.other.rawValue,
            title: name,
            desc: "POI added during walk \(sessionId)",
            lat: lat,
            lng: lng,
            geohash: geohash,
            status: PoiStatus.active.rawValue
        )

        let docId = try await PoiRepository.shared.createPoi(poi)
        print("POI '\(name)' created: \(docId) at (\(lat), \(lng))")
    }

    // MARK: - Auto Features
    func checkAutoStop(targetLocation: CLLocationCoordinate2D, threshold: Double = 50.0) {
        guard case .active = trackingState,
              let lastPoint = trackPoints.last else { return }

        let distance = haversineDistance(
            lat1: lastPoint.lat,
            lng1: lastPoint.lng,
            lat2: targetLocation.latitude,
            lng2: targetLocation.longitude
        )

        if distance < threshold {
            Task {
                try? await stopWalk()
                print("Auto-stopped: Reached destination")
            }
        }
    }

    func checkAutoPause() {
        guard case .active = trackingState,
              let lastUpdate = lastLocationUpdate else { return }

        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)

        // Auto-pause if no movement for 5 minutes
        if timeSinceLastUpdate > 300, statistics.currentSpeed < 0.5 {
            pauseWalk()
            print("Auto-paused: No movement detected")
        }
    }
}

// MARK: - Walk Error
enum WalkError: LocalizedError {
    case noDogSelected
    case walkAlreadyInProgress
    case noActiveWalk
    case sessionNotFound
    case locationPermissionDenied

    var errorDescription: String? {
        switch self {
        case .noDogSelected:
            return "Please select at least one dog to start the walk"
        case .walkAlreadyInProgress:
            return "A walk is already in progress"
        case .noActiveWalk:
            return "No active walk found"
        case .sessionNotFound:
            return "Walk session not found"
        case .locationPermissionDenied:
            return "Location permission is required to track walks"
        }
    }
}

// MARK: - Placeholder Models (to be implemented)
struct Dog: Identifiable {
    let id: String
    let name: String
}

// MARK: - Repository Protocols (to be implemented)
protocol WalkRepository {
    func getActiveSession() async throws -> WalkSession?
    func getSession(sessionId: String) async throws -> WalkSession?
    func getTrackPoints(sessionId: String) async throws -> [WalkTrackPoint]
    func startSession(dogIds: [String]) async throws -> String
    func stopSession(sessionId: String) async throws
    func appendTrackPoint(sessionId: String, lat: Double, lng: Double, accMeters: Float?) async throws -> WalkTrackPoint
}

protocol WalkDogRepository {
    func getDogs(ids: [String]) async throws -> [Dog]
}

// MARK: - Walk Location Mode

/// Mirror of the Kotlin / WalkTrackingService mode token. The Swift VM
/// keeps the same string-coded values so the crash-recovery sheet,
/// diagnostics, and back-end walk records all line up cross-platform.
enum WalkLocationMode: String {
    case walk = "personal"
    case runWith = "runWith"
    case trainingSession = "trainingSession"
    case business = "business"

    /// Pass-through to the underlying WalkTrackingService string.
    var serviceToken: String { rawValue }
}

// MARK: - Walk Location Manager (to be implemented)
class WalkLocationManager: ObservableObject {
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    private let locationSubject = PassthroughSubject<CLLocation, Never>()

    /// Start the underlying location service for a walk session.
    ///
    /// `dogIds` + `mode` carry the same context Android's
    /// `WalkTrackingService.startTracking` takes — without them the
    /// crash-recovery sheet shows "0 dogs tagged" after an unclean exit
    /// because there's nothing to repopulate the dog roster from.
    /// Stored as a side-effect via `WalkTrackingService.shared` so the
    /// service-owned in-flight markers reflect the right walk metadata.
    func startTracking(dogIds: [String] = [], mode: WalkLocationMode = .walk) {
        print("Location tracking started — dogIds=\(dogIds.count) mode=\(mode.rawValue)")
        // Bridge into the shared WalkTrackingService so diagnostics +
        // crash-recovery + auto-resume see the same context.
        // `WalkTrackingService.startTracking` is @MainActor; this method
        // is callable from a nonisolated context (Combine subscribers,
        // background queues), so hop to the main actor explicitly.
        let dogIdsSnapshot = dogIds
        let modeToken = mode.serviceToken
        Task { @MainActor in
            WalkTrackingService.shared.startTracking(
                sessionId: nil,
                dogIds: dogIdsSnapshot,
                mode: modeToken
            )
        }
    }

    func pauseTracking() {
        print("Location tracking paused")
    }

    func resumeTracking() {
        print("Location tracking resumed")
    }

    func stopTracking() {
        print("Location tracking stopped")
    }
}
