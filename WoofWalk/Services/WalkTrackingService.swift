import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit
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
    private let motionService: MotionActivityService
    private let filterPipeline = GPSFilterPipeline()
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

    /// Whether the current pause was triggered automatically by motion detection.
    private var isAutoPaused: Bool = false

    /// Minimum GPS movement (meters) that triggers step-count validation.
    /// If GPS says we moved >30m but pedometer says 0 steps, the GPS point is drift.
    private let gpsStepValidationDistance: Double = 30.0

    /// Time window (seconds) to look back for recent steps when validating GPS.
    private let gpsStepValidationWindow: TimeInterval = 10.0

    private init(locationService: LocationService = .shared, motionService: MotionActivityService = .shared) {
        self.locationService = locationService
        self.motionService = motionService
        setupLocationSubscription()
        setupMotionSubscription()
    }

    private func setupLocationSubscription() {
        locationService.locationUpdatePublisher
            .sink { [weak self] update in
                self?.handleLocationUpdate(update)
            }
            .store(in: &cancellables)
    }

    private func setupMotionSubscription() {
        // Watch for stationary → auto-pause
        motionService.$isStationary
            .removeDuplicates()
            .sink { [weak self] stationary in
                guard let self else { return }
                if stationary {
                    self.handleMotionStationary()
                } else {
                    self.handleMotionResumed()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Motion-Based Auto-Pause / Auto-Resume

    private func handleMotionStationary() {
        guard trackingState.isTracking, !trackingState.isPaused else { return }

        isAutoPaused = true
        trackingState.isPaused = true
        timer?.invalidate()
        showNotification(title: "Walk Auto-Paused", body: "You seem to be standing still")
        print("[AutoPause] Motion-based auto-pause triggered (stationary for \(motionService.stationaryThreshold)s)")
    }

    private func handleMotionResumed() {
        guard trackingState.isTracking, trackingState.isPaused, isAutoPaused else { return }

        isAutoPaused = false
        trackingState.isPaused = false
        startTimer()
        showNotification(title: "Walk Resumed", body: "Movement detected, tracking resumed")
        print("[AutoPause] Motion-based auto-resume triggered")
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

        filterPipeline.start()
        motionService.start()
        isAutoPaused = false

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

        isAutoPaused = false  // Manual pause overrides auto-pause state
        trackingState.isPaused = true
        timer?.invalidate()
        showNotification(title: "Walk Paused", body: "Tap to resume tracking")
        print("Walk tracking paused")
    }

    func resumeTracking() {
        guard trackingState.isTracking, trackingState.isPaused else { return }

        isAutoPaused = false
        trackingState.isPaused = false
        startTimer()
        print("Walk tracking resumed")
    }

    func stopTracking() -> LocalWalkRecord? {
        print("Stopping walk tracking")

        locationService.stopUpdatingLocation()
        locationService.stopUpdatingHeading()
        motionService.stop()
        filterPipeline.reset()
        timer?.invalidate()
        isAutoPaused = false

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

        let rawLocation = CLLocation(
            coordinate: update.coordinate,
            altitude: update.altitude ?? 0,
            horizontalAccuracy: update.accuracy,
            verticalAccuracy: -1,
            course: update.course,
            speed: update.speed,
            timestamp: update.timestamp
        )

        // Run through the full GPS filter pipeline (accuracy, bearing, Kalman, jitter, speed gates)
        guard let filtered = filterPipeline.process(rawLocation) else { return }

        // Step-count GPS drift validation: if GPS says >30m movement but pedometer shows 0 steps,
        // the GPS point is likely drift (e.g. urban canyon multipath) - reject it.
        let distanceFromLast = filterPipeline.lastAcceptedDistance
        if distanceFromLast > gpsStepValidationDistance {
            Task { [weak self] in
                guard let self else { return }
                let recentSteps = await self.motionService.recentSteps(inLast: self.gpsStepValidationWindow)
                if recentSteps == 0 {
                    print("[GPSDrift] Rejected GPS point: \(String(format: "%.1f", distanceFromLast))m movement but 0 steps in last \(self.gpsStepValidationWindow)s")
                    // Don't accumulate this distance - it's phantom movement
                    return
                }
                await self.acceptFilteredLocation(filtered: filtered, update: update, distanceFromLast: distanceFromLast)
            }
            return
        }

        // Normal path (distance <= threshold or step validation not needed)
        acceptFilteredLocation(filtered: filtered, update: update, distanceFromLast: distanceFromLast)
    }

    /// Accepts a filtered GPS location and updates all tracking state.
    /// Called from handleLocationUpdate directly, or after async step-count validation.
    private func acceptFilteredLocation(filtered: CLLocation, update: LocationUpdate, distanceFromLast: Double) {
        let currentTime = Date()
        trackingState.gpsAccuracy = update.accuracy
        trackingState.gpsQuality = update.gpsQuality
        trackingState.currentSpeedMps = update.speed
        trackingState.currentBearing = update.course

        // Accumulate distance from the pipeline's jitter-gated measurement
        if distanceFromLast > 0 {
            totalDistanceMeters += distanceFromLast
        }
        lastLocation = filtered

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
            latitude: filtered.coordinate.latitude,
            longitude: filtered.coordinate.longitude,
            accuracy: filtered.horizontalAccuracy
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
        HapticFeedback.milestone()
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
