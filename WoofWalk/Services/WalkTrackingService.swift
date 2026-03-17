import Foundation
import CoreLocation
import Combine
import UserNotifications

struct WalkTrackingState {
    var isTracking: Bool = false
    var isPaused: Bool = false
    var distanceMeters: Double = 0.0
    var durationSeconds: Int = 0
    var currentPaceKmh: Double = 0.0
    var currentSpeedMps: Double = 0.0
    var polyline: [CLLocationCoordinate2D] = []
    var gpsAccuracy: CLLocationAccuracy = 0
    var gpsQuality: GPSQuality = .unknown
    var lastMilestoneKm: Int = 0
    var caloriesBurned: Int = 0
    var currentBearing: CLLocationDirection = 0
    var elevationGainMeters: Double = 0.0
}

@MainActor
class WalkTrackingService: ObservableObject {
    static let shared = WalkTrackingService()

    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()

    @Published var trackingState = WalkTrackingState()

    private var trackPoints: [LocationTrackPoint] = []
    private var startTime: Date?
    private var totalDistanceMeters: Double = 0
    private var lastMilestoneKm = 0
    private var totalCalories = 0
    private var lastElevation: Double?
    private var totalElevationGain: Double = 0
    private var lastLocationTime: Date?
    private var lastLocation: CLLocation?
    private var timer: Timer?

    private let minAccuracyMeters: CLLocationAccuracy = 50.0
    private let minDistanceMeters: CLLocationDistance = 2.0
    private let autoPauseThresholdMps: CLLocationSpeed = 0.3
    private let autoPauseTimeSeconds: TimeInterval = 30.0

    private init(locationService: LocationService = .shared) {
        self.locationService = locationService
        setupLocationSubscription()
    }

    private func setupLocationSubscription() {
        locationService.locationUpdatePublisher
            .filter { [weak self] update in
                guard let self = self else { return false }
                return update.accuracy <= self.minAccuracyMeters && update.accuracy >= 0
            }
            .sink { [weak self] update in
                self?.handleLocationUpdate(update)
            }
            .store(in: &cancellables)
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard !trackingState.isTracking else {
            print("Already tracking")
            return
        }

        print("Starting walk tracking")

        startTime = Date()
        trackPoints.removeAll()
        totalDistanceMeters = 0
        lastMilestoneKm = 0
        totalCalories = 0
        lastElevation = nil
        totalElevationGain = 0
        lastLocation = nil
        lastLocationTime = nil

        locationService.startUpdatingLocation(
            accuracy: kCLLocationAccuracyBest,
            distanceFilter: kCLDistanceFilterNone
        )

        locationService.startUpdatingHeading()

        startTimer()

        trackingState = WalkTrackingState(
            isTracking: true,
            isPaused: false,
            distanceMeters: 0,
            durationSeconds: 0,
            currentPaceKmh: 0,
            polyline: []
        )

        requestNotificationPermission()
    }

    func pauseTracking() {
        guard trackingState.isTracking, !trackingState.isPaused else { return }

        trackingState.isPaused = true
        timer?.invalidate()
        showNotification(title: "Walk Paused", body: "Tap to resume tracking")
        print("Walk tracking paused")
    }

    func resumeTracking() {
        guard trackingState.isTracking, trackingState.isPaused else { return }

        trackingState.isPaused = false
        startTimer()
        print("Walk tracking resumed")
    }

    func stopTracking() -> LocalWalkRecord? {
        print("Stopping walk tracking")

        locationService.stopUpdatingLocation()
        locationService.stopUpdatingHeading()
        timer?.invalidate()

        let endTime = Date()
        guard let start = startTime else { return nil }

        let durationSec = Int(endTime.timeIntervalSince(start))

        let walkHistory: LocalWalkRecord?
        if !trackPoints.isEmpty {
            walkHistory = LocalWalkRecord(
                distanceMeters: Int(totalDistanceMeters.rounded()),
                durationSec: durationSec,
                track: trackPoints,
                polyline: PolylineEncoder.encode(coordinates: trackPoints.map { $0.coordinate }),
                caloriesBurned: totalCalories,
                elevationGainMeters: totalElevationGain,
                avgSpeedKmh: SpeedETACalculator.calculatePaceKmh(
                    distanceMeters: totalDistanceMeters,
                    durationSeconds: TimeInterval(durationSec)
                )
            )
        } else {
            walkHistory = nil
        }

        trackingState = WalkTrackingState()
        trackPoints.removeAll()
        totalDistanceMeters = 0
        startTime = nil

        if let walk = walkHistory {
            showWalkSavedNotification(walk: walk)
        }

        return walkHistory
    }

    // MARK: - Location Update Handler

    private func handleLocationUpdate(_ update: LocationUpdate) {
        guard trackingState.isTracking, !trackingState.isPaused else { return }

        let location = CLLocation(
            coordinate: update.coordinate,
            altitude: update.altitude ?? 0,
            horizontalAccuracy: update.accuracy,
            verticalAccuracy: -1,
            course: update.course,
            speed: update.speed,
            timestamp: update.timestamp
        )

        checkAutoPause(location: location)

        guard !trackingState.isPaused else { return }

        let currentTime = Date()
        trackingState.gpsAccuracy = update.accuracy
        trackingState.gpsQuality = update.gpsQuality
        trackingState.currentSpeedMps = update.speed
        trackingState.currentBearing = update.course

        if let lastLoc = lastLocation {
            let distance = location.distance(from: lastLoc)

            if distance >= minDistanceMeters {
                totalDistanceMeters += distance
                lastLocation = location
            }
        } else {
            lastLocation = location
        }

        if update.altitude != nil {
            if let prevElevation = lastElevation, let currentAltitude = update.altitude {
                let elevationChange = currentAltitude - prevElevation
                if elevationChange > 0 {
                    totalElevationGain += elevationChange
                }
            }
            lastElevation = update.altitude
        }

        let trackPoint = LocationTrackPoint(
            timestamp: update.timestamp.timeIntervalSince1970,
            latitude: update.coordinate.latitude,
            longitude: update.coordinate.longitude,
            accuracy: update.accuracy
        )

        trackPoints.append(trackPoint)

        guard let start = startTime else { return }
        let durationSec = Int(currentTime.timeIntervalSince(start))

        let currentPace = SpeedETACalculator.calculatePaceKmh(
            distanceMeters: totalDistanceMeters,
            durationSeconds: TimeInterval(durationSec)
        )

        let avgWeightKg = 70.0
        let met = 3.5
        let hoursElapsed = Double(durationSec) / 3600.0
        totalCalories = Int(met * avgWeightKg * hoursElapsed)

        let currentKm = Int(totalDistanceMeters / 1000.0)
        if currentKm > lastMilestoneKm && currentKm > 0 {
            triggerMilestone(km: currentKm)
            lastMilestoneKm = currentKm
        }

        trackingState = WalkTrackingState(
            isTracking: true,
            isPaused: false,
            distanceMeters: totalDistanceMeters,
            durationSeconds: durationSec,
            currentPaceKmh: currentPace,
            currentSpeedMps: update.speed,
            polyline: trackPoints.map { $0.coordinate },
            gpsAccuracy: update.accuracy,
            gpsQuality: update.gpsQuality,
            lastMilestoneKm: lastMilestoneKm,
            caloriesBurned: totalCalories,
            currentBearing: update.course,
            elevationGainMeters: totalElevationGain
        )

        lastLocationTime = currentTime

        if update.gpsQuality == .poor {
            showGPSWarning()
        }

        print("Location: distance=\(totalDistanceMeters)m, pace=\(currentPace), speed=\(update.speed)m/s, GPS=\(update.gpsQuality)")
    }

    private func checkAutoPause(location: CLLocation) {
        guard let lastUpdate = lastLocationTime else { return }

        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)

        if location.speed < autoPauseThresholdMps &&
           timeSinceLastUpdate > autoPauseTimeSeconds &&
           !trackingState.isPaused {
            pauseTracking()
            showNotification(title: "Walk Auto-Paused", body: "You seem to be standing still")
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let start = self.startTime,
                  !self.trackingState.isPaused else { return }

            let durationSec = Int(Date().timeIntervalSince(start))
            self.trackingState.durationSeconds = durationSec
        }
    }

    // MARK: - Milestones

    private func triggerMilestone(km: Int) {
        showNotification(title: "Milestone Reached!", body: "You've walked \(km)km")
        print("Milestone reached: \(km)km")
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    private func showGPSWarning() {
        showNotification(title: "Weak GPS Signal", body: "Go outside for better tracking accuracy")
    }

    private func showWalkSavedNotification(walk: LocalWalkRecord) {
        let distanceKm = Double(walk.distanceMeters) / 1000.0
        let hours = walk.durationSec / 3600
        let minutes = (walk.durationSec % 3600) / 60

        showNotification(
            title: "Walk Saved",
            body: String(format: "%.2f km in %dh %dm", distanceKm, hours, minutes)
        )
    }
}

// MARK: - Local Walk Record (used by WalkTrackingService for in-progress walks)

struct LocalWalkRecord: Codable {
    let id = UUID()
    let distanceMeters: Int
    let durationSec: Int
    let track: [LocationTrackPoint]
    let polyline: String
    let caloriesBurned: Int
    let elevationGainMeters: Double
    let avgSpeedKmh: Double
    let timestamp: Date = Date()

    var distanceKm: Double {
        Double(distanceMeters) / 1000.0
    }

    var formattedDuration: String {
        SpeedETACalculator.formatDuration(TimeInterval(durationSec))
    }

    var formattedDistance: String {
        SpeedETACalculator.formatDistance(Double(distanceMeters))
    }

    var formattedSpeed: String {
        SpeedETACalculator.formatSpeed(avgSpeedKmh)
    }
}
