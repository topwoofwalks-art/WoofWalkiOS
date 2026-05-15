import Foundation
import CoreLocation
import CoreMotion
import Combine
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

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
    /// Stable session ID for the active walk. Used as the SharedPrefs /
    /// UserDefaults key for any per-walk persistence (Watch Me token,
    /// stationary-confirm timer, etc) so a foreground app re-launch
    /// mid-walk can rehydrate state without losing context.
    var sessionId: String?
}

/// Maximum age (seconds) of a `CLLocation` we'll accept into the GPS
/// pipeline. Mirrors Android `MAX_FIX_AGE_NANOS = 30_000_000_000L` —
/// stale fixes cause distance creep when the OS hands back a cached
/// position from before the walk started. CoreLocation usually delivers
/// fresh fixes, but iOS WILL surface stale ones during cold-warmup of
/// the GPS chip or after a `pausesLocationUpdatesAutomatically` resume.
private let maxFixAgeSeconds: TimeInterval = 30.0

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

    /// Wall-clock timestamp the current pause began. Used by the resume watcher
    /// to compare against `motionService.lastStepIncrementAt`.
    private var pauseStartedAt: Date?

    /// Independent timer that polls pedometer state every 5 s while paused.
    /// Triggers auto-resume if a step lands AFTER `pauseStartedAt`. Critical
    /// for screen-off / Doze cases where GPS fixes stop arriving.
    private var resumeWatcherTimer: Timer?

    // MARK: - GPS Pipeline Counters

    /// Total location updates received from CoreLocation.
    @Published private(set) var pipelineFixesReceived: Int = 0
    /// Fixes rejected by `GPSFilterPipeline` (bad accuracy / glitch / time gate).
    @Published private(set) var pipelineFixesRejectedFilter: Int = 0
    /// Fixes rejected by the step-validation gate (GPS moved > 5 m but no steps).
    @Published private(set) var pipelineFixesRejectedStepGate: Int = 0
    /// Fixes rejected by the stationary-drift guard.
    @Published private(set) var pipelineFixesRejectedStationaryGuard: Int = 0
    /// Fixes that survived all gates and updated tracking state.
    @Published private(set) var pipelineFixesAccepted: Int = 0
    /// Wall-clock timestamp of the most recent accepted fix (for RAG indicator age).
    @Published private(set) var lastAcceptedFixAt: Date?

    /// Stationary anchor used by the drift-guard. Set once we have a confident
    /// "user is standing still" signal; cleared as soon as motion resumes.
    private var stationaryAnchor: CLLocationCoordinate2D?

    // MARK: - Walk Diagnostics

    /// Walk-id under which the current diagnostic doc is being built.
    /// Set on `startTracking` from the caller-supplied sessionId; cleared
    /// on `stopTracking`. Used as the Firestore doc id for the
    /// `/users/{uid}/walk_diagnostics/{walkId}` write so iOS and Android
    /// diagnostics for the same logical walk collide on the same doc.
    private var diagnosticsWalkId: String?
    /// Wall-clock ms when the walk started (matches `startTime` but
    /// kept as Int64 to avoid recomputing for every snapshot).
    private var diagnosticsStartedAtMs: Int64 = 0
    /// Per-reason rejection counters. Kept as a String→Int dict so we
    /// can drop it into Firestore without further mapping.
    private var diagnosticsRejections: [String: Int] = [:]
    /// DR-mode samples captured on each accepted fix. Capped at 1000
    /// entries to keep the doc within Firestore's 1 MiB limit.
    private var diagnosticsDrModeHistory: [Bool] = []
    /// Permission flags captured at walk start.
    private var diagForegroundLocAtStart: Bool = false
    private var diagBackgroundLocAtStart: Bool = false
    private var diagPreciseLocAtStart: Bool = false
    private var diagLowPowerModeAtStart: Bool = false
    private var diagMotionPermAtStart: Bool = false
    /// Live mid-walk flags.
    private var diagPermissionRevokedMidWalk: Bool = false
    private var diagLocationServicesOffMidWalk: Bool = false
    private var diagLowPowerModeEnteredMidWalk: Bool = false
    private var diagAutoPauseTriggers: Int = 0
    private var diagManualPauseToggles: Int = 0
    private var diagServiceKillCount: Int = 0
    private var diagWatchdogRecoveryCount: Int = 0

    // MARK: - Watch Me / SafetyWatch State

    /// Active safety watch for the current walk, or `nil` if Watch Me is off.
    @Published private(set) var safetyWatch: SafetyWatch?

    /// True while the `startSafetyWatch` CF round-trip is in flight.
    @Published private(set) var isStartingSafetyWatch: Bool = false

    /// One-shot signal: walker just successfully started Watch Me. UI
    /// uses this to mount `WatchMeSendingSplash`. Cleared via
    /// `consumeSafetyShareEvent()`.
    @Published var safetyShareEvent: SafetyShareEvent?

    /// One-shot error banner for failed `startSafetyWatch` CF calls. The
    /// share intent has already fired by the time we know the CF failed,
    /// so the walker needs explicit feedback that their link won't work.
    @Published var safetyWatchStartError: String?

    /// Per-action in-flight flag exposed for UI debounces. Buttons that
    /// trigger CF round-trips (I'M OK, PANIC, Arrived, Cancel) read this
    /// to disable themselves while a call is in flight.
    @Published private(set) var safetyActionInFlight: Bool = false

    /// One-shot toast text for failed safety actions. UI consumes via
    /// `consumeSafetyActionError()`.
    @Published var safetyActionError: String?

    /// Show the full-screen check-in prompt. Driven by the stationary
    /// watcher: if the walker hasn't moved >15 m for 5 minutes during an
    /// active SafetyWatch, this flips on with audio + haptic.
    @Published var checkInPromptVisible: Bool = false

    private let safetyWatchRepository = SafetyWatchRepository.shared
    private var lastSafetyWatchPushTime: Date?

    /// Last filtered GPS fix that moved >15 m from the previous accepted
    /// position. Drives the 5-min stationary check-in trigger.
    private var lastSignificantMovementAt: Date?
    private var lastSignificantLat: Double = .nan
    private var lastSignificantLng: Double = .nan

    private init(locationService: LocationService = .shared, motionService: MotionActivityService = .shared) {
        self.locationService = locationService
        self.motionService = motionService
        setupLocationSubscription()
        setupMotionSubscription()
        setupBackgroundObserver()
    }

    /// Watch for the app being backgrounded mid-walk. We snapshot
    /// diagnostics to Firestore at that point so that if the OS kills
    /// us before stopTracking() runs (low memory, force-quit, runaway
    /// background-task expiration) we still have a forensic record.
    /// Mirrors the safety-net behaviour of Android's
    /// `WalkDiagnosticsStore.heartbeat()`.
    private func setupBackgroundObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.snapshotDiagnosticsOnBackground()
            }
        }
    }

    private func setupLocationSubscription() {
        locationService.locationUpdatePublisher
            .sink { [weak self] update in
                self?.handleLocationUpdate(update)
            }
            .store(in: &cancellables)
    }

    private func setupMotionSubscription() {
        // Watch for stationary → auto-pause + drift-guard anchor
        motionService.$isStationary
            .removeDuplicates()
            .sink { [weak self] stationary in
                guard let self else { return }
                if stationary {
                    // Anchor the drift-guard at the last accepted GPS fix
                    if let last = self.lastLocation {
                        self.stationaryAnchor = last.coordinate
                    }
                    self.handleMotionStationary()
                } else {
                    self.stationaryAnchor = nil
                    self.handleMotionResumed()
                }
            }
            .store(in: &cancellables)

        // Watch for pedometer ticks while paused → auto-resume.
        // Combine path: any new step-increment timestamp triggers a re-eval.
        motionService.$lastStepIncrementAt
            .compactMap { $0 }
            .sink { [weak self] stepAt in
                guard let self else { return }
                self.evaluatePedometerResume(stepAt: stepAt)
            }
            .store(in: &cancellables)
    }

    // MARK: - Motion-Based Auto-Pause / Auto-Resume

    private func handleMotionStationary() {
        guard trackingState.isTracking, !trackingState.isPaused else { return }

        isAutoPaused = true
        trackingState.isPaused = true
        pauseStartedAt = Date()
        diagAutoPauseTriggers += 1
        // Persist the pause-start timestamp so an app re-launch during the
        // 170-s confirmation window doesn't lose the timer. Mirrors
        // Android `WalkTrackingService.lastStationaryCheckTime` persistence.
        if let sid = trackingState.sessionId {
            UserDefaults.standard.set(pauseStartedAt!.timeIntervalSince1970,
                                      forKey: "walkTracking.\(sid).pauseStartedAt")
        }
        timer?.invalidate()
        startResumeWatcher()
        showNotification(title: "Walk Auto-Paused", body: "You seem to be standing still")
        print("[AutoPause] Motion-based auto-pause triggered (stationary for \(motionService.stationaryThreshold)s)")
    }

    private func handleMotionResumed() {
        // Activity detector said "moving again" — that alone is enough to resume.
        triggerResume(reason: "activity-detector")
    }

    /// Broadened resume gate: resume on ANY of
    ///   - speed > 0.5 m/s
    ///   - drift > 10 m from stationary anchor
    ///   - pedometer ticked since pause began
    /// Mirrors Android's broadened `evaluateResume` logic.
    private func evaluateBroadenedResume(currentSpeed: Double, currentCoord: CLLocationCoordinate2D) {
        guard trackingState.isTracking, trackingState.isPaused, isAutoPaused else { return }

        // 1. Speed gate
        if currentSpeed > 0.5 {
            triggerResume(reason: "speed>0.5 (\(String(format: "%.2f", currentSpeed)) m/s)")
            return
        }

        // 2. Drift-from-anchor gate
        if let anchor = stationaryAnchor {
            let drift = GPSFilterPipeline.haversineDistance(
                lat1: anchor.latitude, lng1: anchor.longitude,
                lat2: currentCoord.latitude, lng2: currentCoord.longitude
            )
            if drift > 10.0 {
                triggerResume(reason: "drift \(String(format: "%.1f", drift))m > 10m")
                return
            }
        }

        // 3. Pedometer-since-pause gate
        if let pauseAt = pauseStartedAt,
           let stepAt = motionService.lastStepIncrementAt,
           stepAt > pauseAt {
            triggerResume(reason: "pedometer-tick after pause")
            return
        }
    }

    /// Called by the resume watcher (5 s timer) and the pedometer Combine sink.
    private func evaluatePedometerResume(stepAt: Date) {
        guard trackingState.isTracking, trackingState.isPaused, isAutoPaused else { return }
        guard let pauseAt = pauseStartedAt else { return }
        if stepAt > pauseAt {
            triggerResume(reason: "pedometer-tick (poll)")
        }
    }

    private func triggerResume(reason: String) {
        guard trackingState.isTracking, trackingState.isPaused, isAutoPaused else { return }
        isAutoPaused = false
        trackingState.isPaused = false
        pauseStartedAt = nil
        if let sid = trackingState.sessionId {
            UserDefaults.standard.removeObject(forKey: "walkTracking.\(sid).pauseStartedAt")
        }
        stopResumeWatcher()
        startTimer()
        showNotification(title: "Walk Resumed", body: "Movement detected, tracking resumed")
        print("[AutoPause] Auto-resume triggered (\(reason))")
    }

    /// 5-second poll timer that fires while paused. Independent of GPS / activity
    /// updates so it survives screen-off + Doze-like power states where neither
    /// signal is delivered.
    private func startResumeWatcher() {
        resumeWatcherTimer?.invalidate()
        resumeWatcherTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let pauseAt = self.pauseStartedAt,
                      let stepAt = self.motionService.lastStepIncrementAt else { return }
                if stepAt > pauseAt {
                    self.triggerResume(reason: "pedometer-tick (5s poll)")
                }
            }
        }
    }

    private func stopResumeWatcher() {
        resumeWatcherTimer?.invalidate()
        resumeWatcherTimer = nil
    }

    // MARK: - Tracking Control

    func startTracking(sessionId: String? = nil, dogIds: [String] = [], mode: String = "personal") {
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

        let sid = sessionId ?? UUID().uuidString

        // Reset all per-walk diagnostics state + capture the at-start
        // permission / power snapshot. Mirrors Android's
        // `WalkDiagnosticsStore.captureAtStart`.
        diagnosticsWalkId = sid
        diagnosticsStartedAtMs = Int64(startTime!.timeIntervalSince1970 * 1000)
        diagnosticsRejections.removeAll()
        diagnosticsDrModeHistory.removeAll()
        diagPermissionRevokedMidWalk = false
        diagLocationServicesOffMidWalk = false
        diagLowPowerModeEnteredMidWalk = false
        diagAutoPauseTriggers = 0
        diagManualPauseToggles = 0
        diagWatchdogRecoveryCount = 0
        captureDiagnosticsAtStart()

        // ── In-flight walk markers for backgrounded-crash recovery ──
        // Mirrors Android `WalkBootReceiver` which reads Room for an
        // unfinished session on BOOT_COMPLETED. iOS can't be restarted
        // by the OS post-kill the same way, but we can still detect
        // "previous launch had a walk in flight" on cold-start and
        // offer to resume / finalise. Keys are cleared in
        // `stopTracking()` so a clean stop doesn't leave a ghost.
        UserDefaults.standard.set(sid, forKey: Self.inflightWalkIdKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970,
                                  forKey: Self.inflightWalkStartedAtKey)
        if let dogJson = try? JSONSerialization.data(withJSONObject: dogIds),
           let dogStr = String(data: dogJson, encoding: .utf8) {
            UserDefaults.standard.set(dogStr, forKey: Self.inflightWalkDogIdsKey)
        }
        UserDefaults.standard.set(mode, forKey: Self.inflightWalkModeKey)

        filterPipeline.start()
        motionService.start(sessionId: sid)
        isAutoPaused = false
        pauseStartedAt = nil
        stationaryAnchor = nil
        stopResumeWatcher()
        lastSignificantMovementAt = nil
        lastSignificantLat = .nan
        lastSignificantLng = .nan

        // Restore any persisted stationary-confirm timer so an app
        // re-launch mid-walk doesn't reset the auto-pause clock.
        // Mirrors Android `lastStationaryCheckTime` SharedPrefs persistence.
        let persistedKey = "walkTracking.\(sid).pauseStartedAt"
        if let raw = UserDefaults.standard.object(forKey: persistedKey) as? Double {
            pauseStartedAt = Date(timeIntervalSince1970: raw)
        }

        // Reset GPS pipeline counters
        pipelineFixesReceived = 0
        pipelineFixesRejectedFilter = 0
        pipelineFixesRejectedStepGate = 0
        pipelineFixesRejectedStationaryGuard = 0
        pipelineFixesAccepted = 0
        lastAcceptedFixAt = nil

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
            polyline: [],
            sessionId: sid
        )

        requestNotificationPermission()
    }

    func pauseTracking() {
        guard trackingState.isTracking, !trackingState.isPaused else { return }

        isAutoPaused = false  // Manual pause overrides auto-pause state
        trackingState.isPaused = true
        pauseStartedAt = nil   // Manual pause does not arm the resume watcher
        stopResumeWatcher()
        timer?.invalidate()
        diagManualPauseToggles += 1
        showNotification(title: "Walk Paused", body: "Tap to resume tracking")
        print("Walk tracking paused")
    }

    func resumeTracking() {
        guard trackingState.isTracking, trackingState.isPaused else { return }

        isAutoPaused = false
        trackingState.isPaused = false
        pauseStartedAt = nil
        stopResumeWatcher()
        startTimer()
        diagManualPauseToggles += 1
        print("Walk tracking resumed")
    }

    func stopTracking() -> LocalWalkRecord? {
        print("Stopping walk tracking")

        // Clear any persisted per-walk state before we drop sessionId.
        if let sid = trackingState.sessionId {
            UserDefaults.standard.removeObject(forKey: "walkTracking.\(sid).pauseStartedAt")
        }

        // Clear in-flight walk markers — a clean stop means there's
        // nothing to recover on next launch.
        UserDefaults.standard.removeObject(forKey: Self.inflightWalkIdKey)
        UserDefaults.standard.removeObject(forKey: Self.inflightWalkStartedAtKey)
        UserDefaults.standard.removeObject(forKey: Self.inflightWalkDogIdsKey)
        UserDefaults.standard.removeObject(forKey: Self.inflightWalkModeKey)

        locationService.stopUpdatingLocation()
        locationService.stopUpdatingHeading()
        motionService.stop()
        filterPipeline.reset()
        timer?.invalidate()
        stopResumeWatcher()
        isAutoPaused = false
        pauseStartedAt = nil
        stationaryAnchor = nil
        lastSignificantMovementAt = nil
        lastSignificantLat = .nan
        lastSignificantLng = .nan
        safetyWatch = nil
        checkInPromptVisible = false

        let endTime = Date()
        guard let start = startTime else { return nil }

        let durationSec = Int(endTime.timeIntervalSince(start))

        let walkHistory: LocalWalkRecord?
        if !trackPoints.isEmpty {
            // Post-process the raw track through the full cleaning pipeline
            let rawPoints = trackPoints.map { point in
                GpsPostProcessor.RawPoint(
                    coordinate: point.coordinate,
                    timestamp: point.timestamp,
                    accuracy: point.accuracy
                )
            }
            let processed = GpsPostProcessor.process(rawPoints)

            print("[PostProcess] \(processed.originalCount) raw -> \(processed.points.count) cleaned (\(processed.pointsRemoved) removed), distance=\(String(format: "%.0f", processed.distanceMeters))m")

            // Build cleaned track points from post-processed coordinates
            let cleanedTrack = processed.points.enumerated().map { idx, coord in
                LocationTrackPoint(
                    timestamp: idx < trackPoints.count ? trackPoints[idx].timestamp : trackPoints.last!.timestamp,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    accuracy: idx < trackPoints.count ? trackPoints[idx].accuracy : trackPoints.last!.accuracy
                )
            }

            walkHistory = LocalWalkRecord(
                distanceMeters: Int(processed.distanceMeters.rounded()),
                durationSec: durationSec,
                track: cleanedTrack,
                polyline: PolylineEncoder.encode(coordinates: processed.points),
                caloriesBurned: totalCalories,
                elevationGainMeters: totalElevationGain,
                avgSpeedKmh: SpeedETACalculator.calculatePaceKmh(
                    distanceMeters: processed.distanceMeters,
                    durationSeconds: TimeInterval(durationSec)
                )
            )
        } else {
            walkHistory = nil
        }

        // Ship a final diagnostics snapshot. Captures live + processed
        // distance so we can spot post-process divergence post-hoc.
        let processedDistance = walkHistory.map { Double($0.distanceMeters) } ?? totalDistanceMeters
        let trackPointCountFinal = walkHistory?.track.count ?? trackPoints.count
        shipDiagnosticsSnapshot(
            finalDistanceMeters: processedDistance,
            trackPointCount: trackPointCountFinal,
            isFinalWrite: true
        )

        trackingState = WalkTrackingState()
        trackPoints.removeAll()
        totalDistanceMeters = 0
        startTime = nil
        diagnosticsWalkId = nil

        if let walk = walkHistory {
            showWalkSavedNotification(walk: walk)
        }

        return walkHistory
    }

    // MARK: - Location Update Handler

    private func handleLocationUpdate(_ update: LocationUpdate) {
        guard trackingState.isTracking else { return }

        pipelineFixesReceived += 1

        // Stale-fix gate (mirrors Android `MAX_FIX_AGE_NANOS = 30s`).
        // CoreLocation can hand back a cached fix from before the walk
        // started, especially during cold-warmup of the GPS chip or after
        // the OS resumed from pausesLocationUpdatesAutomatically. Reject
        // anything older than 30 s to stop those phantom early fixes from
        // teleporting our anchor across town.
        let fixAge = Date().timeIntervalSince(update.timestamp)
        if fixAge > maxFixAgeSeconds {
            pipelineFixesRejectedFilter += 1
            diagnosticsRejections[WalkDiagnostics.RejectionReason.stale.rawValue, default: 0] += 1
            print("[GPSGuard] Rejected stale fix: \(String(format: "%.1f", fixAge))s old (limit \(maxFixAgeSeconds)s)")
            return
        }

        // While paused, we still want to evaluate the broadened resume gate so
        // movement can wake the walk back up via GPS-speed or drift-from-anchor.
        if trackingState.isPaused {
            evaluateBroadenedResume(currentSpeed: update.speed, currentCoord: update.coordinate)
            return
        }

        let rawLocation = CLLocation(
            coordinate: update.coordinate,
            altitude: update.altitude ?? 0,
            horizontalAccuracy: update.accuracy,
            verticalAccuracy: -1,
            course: update.course,
            speed: update.speed,
            timestamp: update.timestamp
        )

        // Run through permissive GPS filter pipeline (Kalman smoothing only, post-process after walk)
        guard let filtered = filterPipeline.process(rawLocation) else {
            pipelineFixesRejectedFilter += 1
            diagnosticsRejections[WalkDiagnostics.RejectionReason.filter.rawValue, default: 0] += 1
            return
        }

        let distanceFromLast = filterPipeline.lastAcceptedDistance

        // Stationary-drift guard:
        // If the motion service is confident the user is stationary AND we have
        // an anchor coordinate, reject any new fix that's > 0.5 m from the anchor.
        // This is pure GPS drift while standing still — accepting it would
        // accumulate 15-25 m of phantom movement over a few minutes.
        if motionService.isStationary, let anchor = stationaryAnchor {
            let drift = GPSFilterPipeline.haversineDistance(
                lat1: anchor.latitude, lng1: anchor.longitude,
                lat2: filtered.coordinate.latitude, lng2: filtered.coordinate.longitude
            )
            if drift > 0.5 {
                pipelineFixesRejectedStationaryGuard += 1
                diagnosticsRejections[WalkDiagnostics.RejectionReason.stationaryGuard.rawValue, default: 0] += 1
                print("[GPSGuard] Rejected stationary drift: \(String(format: "%.2f", drift))m from anchor")
                return
            }
        }

        // Pedometer-primary step-validation gate (tightened to mirror
        // Android `WalkTrackingService` line ~1145):
        //
        // If GPS reports > 0.5 m of movement AND >1 s has passed since the
        // last accepted fix, query the pedometer for steps in the last
        // 1.5 s. Zero steps + non-trivial GPS displacement = drift; reject.
        // If the pedometer is unavailable (-1), we fall back to the existing
        // motionService.isStationary anchor guard above and accept the fix.
        let timeSinceLastAccept: TimeInterval = lastLocationTime.map { Date().timeIntervalSince($0) } ?? .infinity
        if distanceFromLast > 0.5, timeSinceLastAccept > 1.0,
           motionService.motionAuthorisationStatus == .authorized {
            let capturedFiltered = filtered
            let capturedUpdate = update
            let capturedDistance = distanceFromLast
            Task { @MainActor [weak self] in
                guard let self else { return }
                let steps = await self.motionService.recentSteps(inLast: 1.5)
                if steps == 0 {
                    self.pipelineFixesRejectedStepGate += 1
                    self.diagnosticsRejections[WalkDiagnostics.RejectionReason.stepGate.rawValue, default: 0] += 1
                    print("[GPSGuard] Rejected fix: \(String(format: "%.2f", capturedDistance))m moved but 0 steps in 1.5s")
                    return
                }
                self.acceptFilteredLocation(
                    filtered: capturedFiltered,
                    update: capturedUpdate,
                    distanceFromLast: capturedDistance
                )
            }
            return
        }

        acceptFilteredLocation(filtered: filtered, update: update, distanceFromLast: distanceFromLast)
    }

    /// Accepts a filtered GPS location and updates all tracking state.
    /// Called from handleLocationUpdate directly, or after async step-count validation.
    private func acceptFilteredLocation(filtered: CLLocation, update: LocationUpdate, distanceFromLast: Double) {
        // Re-check tracking state — async step validation might re-enter after
        // the user manually paused or stopped the walk.
        guard trackingState.isTracking, !trackingState.isPaused else { return }

        let currentTime = Date()
        pipelineFixesAccepted += 1
        lastAcceptedFixAt = currentTime
        // DR-mode sample. iOS doesn't have a separate dead-reckoning
        // pipeline yet (Android-only), so this is currently always
        // false — but recording the false-vector lets us swap in a
        // real DR signal later without changing the doc schema. Cap
        // at 1000 samples to bound Firestore doc size.
        if diagnosticsDrModeHistory.count < 1000 {
            diagnosticsDrModeHistory.append(false)
        }
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

        // SafetyWatch hooks: push location every 10 s + track significant
        // movement so the 5-min stationary check-in trigger has an anchor.
        updateSafetyWatchLocation(lat: filtered.coordinate.latitude,
                                  lng: filtered.coordinate.longitude)
        evaluateSignificantMovement(lat: filtered.coordinate.latitude,
                                    lng: filtered.coordinate.longitude)

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

    // MARK: - Watch Me / SafetyWatch lifecycle

    /// One-shot share event consumed by `WatchMeSendingSplash`. Mirrors
    /// Android `SafetyShareEvent`.
    struct SafetyShareEvent: Equatable {
        let url: String
        let shareText: String
        let guardianPhones: [String]
        let sendMethod: WatchSendMethod
    }

    /// Starts a Watch Me session for the active walk. Pre-generates the
    /// watch token client-side and fires the share intent IMMEDIATELY,
    /// in parallel with the CF call that creates the `/safety_watches`
    /// doc. The previous flow waited for the full CF round-trip
    /// (600-900 ms typical) before WhatsApp / SMS opened — felt sluggish
    /// on every Watch Me start. The portal page polls for the doc and
    /// shows "Setting up..." for the few hundred ms before the CF write
    /// lands. Worst case a guardian taps the link while the doc is still
    /// being created and sees the polling spinner for one extra cycle.
    ///
    /// Mirrors Android `WalkTrackingViewModel.startSafetyWatch`.
    func startSafetyWatch(
        walkerFirstName: String,
        guardianNames: [String],
        guardianPhones: [String],
        guardianUids: [String],
        walkerNote: String,
        expectedReturnAt: Int64,
        sendMethod: WatchSendMethod = .none
    ) {
        guard let sessionId = trackingState.sessionId else {
            print("[SafetyWatch] Cannot start safety watch: no active walk")
            return
        }

        // 32-char hex UUID — matches the CF's stored format
        // (functions/src/notifications/watchMe.ts strips hyphens after
        // generating). The CF accepts our token after a UUID-shape
        // sanity check (`TOKEN_RE`).
        let clientToken = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        let url = safetyWatchRepository.watchUrl(token: clientToken)
        let shareText = buildSafetyShareText(
            walkerFirstName: walkerFirstName,
            walkerNote: walkerNote,
            expectedReturnAt: expectedReturnAt,
            url: url
        )

        // Fire share intent first — user perceives WhatsApp opening
        // immediately rather than after the CF round-trip.
        safetyShareEvent = SafetyShareEvent(
            url: url,
            shareText: shareText,
            guardianPhones: guardianPhones,
            sendMethod: sendMethod
        )

        Task { @MainActor in
            isStartingSafetyWatch = true
            do {
                let watch = try await safetyWatchRepository.startWatch(
                    sessionId: sessionId,
                    walkerFirstName: walkerFirstName,
                    walkerNote: walkerNote,
                    guardianNames: guardianNames,
                    guardianPhones: guardianPhones,
                    guardianUids: guardianUids,
                    expectedReturnAt: expectedReturnAt,
                    clientToken: clientToken
                )
                safetyWatch = watch
                print("[SafetyWatch] Started for session \(sessionId) (token=\(clientToken))")
            } catch {
                print("[SafetyWatch] Failed to start safety watch — share intent already fired with token=\(clientToken): \(error)")
                // The share has already left the building; surface the
                // error so the walker knows the link they sent won't
                // resolve to a live watch.
                safetyWatchStartError = "Couldn't set up Watch Me. Your guardian got the link but won't see live updates. Tap to retry."
            }
            isStartingSafetyWatch = false
        }
    }

    /// Walker tapped the green I'M OK button.
    func checkInSafety() {
        guard let watch = safetyWatch else { return }
        if safetyActionInFlight { return }  // debounce rapid-tap

        // Optimistic — UI flips instantly, CF call runs in background.
        let previous = watch
        var updated = watch
        updated.lastCheckInAt = Int64(Date().timeIntervalSince1970 * 1000)
        updated.status = SafetyWatchStatus.active.rawValue
        safetyWatch = updated
        checkInPromptVisible = false
        lastSignificantMovementAt = Date()
        safetyActionInFlight = true

        Task { @MainActor in
            do {
                try await safetyWatchRepository.recordCheckIn(watchId: watch.id)
            } catch {
                print("[SafetyWatch] check-in CF failed: \(error)")
                // Revert optimistic update + surface to user.
                safetyWatch = previous
                safetyActionError = "Couldn't send check-in. Try again."
            }
            safetyActionInFlight = false
        }
    }

    /// Walker confirmed PANIC (long-press completed).
    func triggerSafetyPanic() {
        guard let watch = safetyWatch else { return }
        if safetyActionInFlight { return }

        let previous = watch
        var updated = watch
        updated.panicTriggeredAt = Int64(Date().timeIntervalSince1970 * 1000)
        updated.status = SafetyWatchStatus.panic.rawValue
        safetyWatch = updated
        checkInPromptVisible = false
        safetyActionInFlight = true

        Task { @MainActor in
            do {
                try await safetyWatchRepository.triggerPanic(watchId: watch.id)
                // CF success — guardian alarms are firing. Stay in PANIC state.
            } catch {
                print("[SafetyWatch] panic CF failed: \(error)")
                // Revert + LOUD error surface — walker thought help was on
                // the way; need to know it isn't. Don't keep the watch in
                // a fake PANIC state because the guardian would never
                // actually have been alerted.
                safetyWatch = previous
                safetyActionError = "ALERT FAILED — guardian was NOT notified. Check your connection and try again, or call 999."
            }
            safetyActionInFlight = false
        }
    }

    /// Walker confirmed they arrived safely. Final state.
    func endSafetyWatchArrived() {
        guard let watch = safetyWatch else { return }
        if safetyActionInFlight { return }
        safetyActionInFlight = true

        Task { @MainActor in
            do {
                try await safetyWatchRepository.markArrived(watchId: watch.id)
                safetyWatch = nil
            } catch {
                print("[SafetyWatch] markArrived failed: \(error)")
                safetyActionError = "Couldn't mark you as arrived. The watch will auto-expire soon."
            }
            safetyActionInFlight = false
        }
    }

    func cancelSafetyWatch() {
        guard let watch = safetyWatch else { return }
        if safetyActionInFlight { return }
        safetyActionInFlight = true

        Task { @MainActor in
            do {
                try await safetyWatchRepository.cancelWatch(watchId: watch.id)
                safetyWatch = nil
            } catch {
                print("[SafetyWatch] cancel failed: \(error)")
                safetyActionError = "Couldn't cancel watch. It'll expire automatically."
            }
            safetyActionInFlight = false
        }
    }

    func dismissCheckInPrompt() {
        checkInPromptVisible = false
        // Snooze for the next 5-min window — record the dismissal as a
        // movement anchor so the next prompt isn't immediate.
        lastSignificantMovementAt = Date()
    }

    func consumeSafetyShareEvent() { safetyShareEvent = nil }
    func consumeSafetyActionError() { safetyActionError = nil }
    func clearSafetyWatchStartError() { safetyWatchStartError = nil }

    // MARK: - Watch Me internals

    /// Push the latest GPS fix onto the watch doc. Throttled to 10 s but
    /// always lets the FIRST push through so the guardian's portal page
    /// exits "Waiting for first GPS fix from X" the moment we have a fix.
    private func updateSafetyWatchLocation(lat: Double, lng: Double) {
        guard let watch = safetyWatch else { return }
        let now = Date()
        if let last = lastSafetyWatchPushTime, now.timeIntervalSince(last) < 10.0 {
            return
        }
        lastSafetyWatchPushTime = now

        let routePoints: [[String: Double]] = trackPoints.map {
            ["lat": $0.latitude, "lng": $0.longitude]
        }
        let distance = totalDistanceMeters
        let durationSec = Int64(trackingState.durationSeconds)

        Task { @MainActor in
            do {
                try await safetyWatchRepository.pushLocation(
                    watchId: watch.id,
                    lat: lat,
                    lng: lng,
                    distanceMeters: distance,
                    durationSec: durationSec,
                    routePoints: routePoints
                )
            } catch {
                print("[SafetyWatch] push location failed: \(error)")
            }
        }
    }

    /// Track significant (>15 m) movement for the 5-min stationary
    /// check-in trigger. If we go 5 minutes without 15 m of progress
    /// during an active SafetyWatch, fire the check-in prompt.
    private func evaluateSignificantMovement(lat: Double, lng: Double) {
        let now = Date()

        // Bootstrap on first accepted fix.
        if lastSignificantMovementAt == nil || lastSignificantLat.isNaN {
            lastSignificantMovementAt = now
            lastSignificantLat = lat
            lastSignificantLng = lng
            return
        }

        let drift = GPSFilterPipeline.haversineDistance(
            lat1: lastSignificantLat, lng1: lastSignificantLng,
            lat2: lat, lng2: lng
        )
        if drift > 15.0 {
            lastSignificantMovementAt = now
            lastSignificantLat = lat
            lastSignificantLng = lng
            return
        }

        // No significant movement — check if 5 min have elapsed during an
        // active SafetyWatch. Don't re-fire while the prompt is already up.
        guard safetyWatch != nil, !checkInPromptVisible else { return }
        if let lastMove = lastSignificantMovementAt,
           now.timeIntervalSince(lastMove) > 300 {
            checkInPromptVisible = true
        }
    }

    /// Render the SMS / WhatsApp body with the walker's note + ETA + URL.
    /// Mirrors Android `buildSafetyShareText`.
    private func buildSafetyShareText(
        walkerFirstName: String,
        walkerNote: String,
        expectedReturnAt: Int64,
        url: String
    ) -> String {
        var lines: [String] = []
        let nameToken = walkerFirstName.isEmpty ? "I" : walkerFirstName
        lines.append("Hey — \(nameToken)'m heading out for a walk. Can you keep an eye on me?")

        if !walkerNote.isEmpty {
            lines.append("")
            lines.append(walkerNote)
        }

        if expectedReturnAt > 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(expectedReturnAt) / 1000.0)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            lines.append("")
            lines.append("Expected back by \(formatter.string(from: date)).")
        }

        lines.append("")
        lines.append("Live route + check-ins here:")
        lines.append(url)
        lines.append("")
        lines.append("(Sent via WoofWalk Watch Me — if I don't check in or hit the alert button, please give me a call.)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Walk Diagnostics + In-flight Markers

    /// UserDefaults keys used by the backgrounded-crash recovery path
    /// (Android `WalkBootReceiver` parity).
    static let inflightWalkIdKey = "walkTracking.inflightWalkId"
    static let inflightWalkStartedAtKey = "walkTracking.inflightWalkStartedAt"
    static let inflightWalkDogIdsKey = "walkTracking.inflightWalkDogIds"
    static let inflightWalkModeKey = "walkTracking.inflightWalkMode"

    /// Capture the at-start permission / power snapshot for the
    /// diagnostics doc. Runs once on `startTracking()` after the
    /// counters have been reset.
    private func captureDiagnosticsAtStart() {
        let authStatus = locationService.authorizationStatus
        diagForegroundLocAtStart = authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways
        diagBackgroundLocAtStart = authStatus == .authorizedAlways
        diagPreciseLocAtStart = !locationService.hasReducedAccuracy
        diagLowPowerModeAtStart = ProcessInfo.processInfo.isLowPowerModeEnabled
        diagMotionPermAtStart = motionService.motionAuthorisationStatus == .authorized
    }

    /// Build a `WalkDiagnostics` from the current in-memory state.
    /// Mirrors Android `WalkTrackingService.diagnosticsSnapshot()`.
    private func diagnosticsSnapshot(finalDistanceMeters: Double? = nil,
                                     trackPointCount: Int? = nil) -> WalkDiagnostics {
        let now = Date()
        var snapshot = WalkDiagnostics()
        snapshot.walkId = diagnosticsWalkId ?? ""
        snapshot.userId = Auth.auth().currentUser?.uid ?? ""
        snapshot.startedAtMs = diagnosticsStartedAtMs
        snapshot.endedAtMs = Int64(now.timeIntervalSince1970 * 1000)

        snapshot.deviceManufacturer = "Apple"
        snapshot.deviceModel = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        snapshot.iosVersion = osVersion
        snapshot.iosMajorVersion = Int(osVersion.split(separator: ".").first.map(String.init) ?? "") ?? 0
        if let info = Bundle.main.infoDictionary {
            snapshot.appVersionName = info["CFBundleShortVersionString"] as? String ?? ""
            snapshot.appVersionCode = Int(info["CFBundleVersion"] as? String ?? "") ?? 0
        }

        snapshot.foregroundLocationAtStart = diagForegroundLocAtStart
        snapshot.backgroundLocationAtStart = diagBackgroundLocAtStart
        snapshot.preciseLocationAtStart = diagPreciseLocAtStart
        snapshot.lowPowerModeAtStart = diagLowPowerModeAtStart
        snapshot.motionPermissionAtStart = diagMotionPermAtStart

        snapshot.fixesReceived = pipelineFixesReceived
        snapshot.fixesAccepted = pipelineFixesAccepted
        snapshot.fixesRejected = diagnosticsRejections
        snapshot.drModeHistory = diagnosticsDrModeHistory

        // End-of-walk permission flicker capture — start vs. end lets
        // us spot mid-walk revocations even if the live flag missed.
        let endAuth = locationService.authorizationStatus
        let endForeground = endAuth == .authorizedWhenInUse || endAuth == .authorizedAlways
        let endBackground = endAuth == .authorizedAlways
        snapshot.permissionsSnapshot = [
            "foregroundLocation": endForeground,
            "backgroundLocation": endBackground,
            "preciseLocation": !locationService.hasReducedAccuracy,
            "motion": motionService.motionAuthorisationStatus == .authorized,
            "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
        ]
        // Synthesise the mid-walk flags from the start vs. end deltas.
        if diagForegroundLocAtStart && !endForeground {
            diagPermissionRevokedMidWalk = true
        }
        if diagBackgroundLocAtStart && !endBackground {
            diagPermissionRevokedMidWalk = true
        }
        if !diagLowPowerModeAtStart && ProcessInfo.processInfo.isLowPowerModeEnabled {
            diagLowPowerModeEnteredMidWalk = true
        }
        snapshot.permissionRevokedMidWalk = diagPermissionRevokedMidWalk
        snapshot.locationServicesOffMidWalk = diagLocationServicesOffMidWalk
        snapshot.lowPowerModeEnteredMidWalk = diagLowPowerModeEnteredMidWalk
        snapshot.autoPauseTriggers = diagAutoPauseTriggers
        snapshot.manualPauseToggles = diagManualPauseToggles
        snapshot.serviceKillCount = diagServiceKillCount
        snapshot.watchdogRecoveryCount = diagWatchdogRecoveryCount

        snapshot.totalDistanceMeters = totalDistanceMeters
        snapshot.finalDistanceMeters = finalDistanceMeters ?? totalDistanceMeters
        snapshot.trackPointCount = trackPointCount ?? trackPoints.count
        snapshot.elevationGainMeters = totalElevationGain
        if let start = startTime {
            snapshot.wallClockDurationSec = Int(now.timeIntervalSince(start))
        }

        // 90-day Firestore TTL — mirrors Android commit 96c8ab3 on the
        // server side. The TTL policy must be enabled once per project
        // via `gcloud firestore fields ttls update expiresAt`.
        snapshot.expiresAt = Timestamp(
            date: Date(timeIntervalSince1970: now.timeIntervalSince1970 + (90 * 24 * 60 * 60))
        )

        return snapshot
    }

    /// Ship the current diagnostics state to Firestore at
    /// `/users/{uid}/walk_diagnostics/{walkId}`. Async, fire-and-forget;
    /// failures are non-fatal (logged only) so a diagnostics write
    /// can never break the walk-stop user flow. Mirrors Android
    /// `WalkSessionRepository.writeWalkDiagnostics`.
    private func shipDiagnosticsSnapshot(
        finalDistanceMeters: Double? = nil,
        trackPointCount: Int? = nil,
        isFinalWrite: Bool
    ) {
        guard let walkId = diagnosticsWalkId, !walkId.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[WalkDiagnostics] Skipping write — no signed-in user")
            return
        }

        let snapshot = diagnosticsSnapshot(
            finalDistanceMeters: finalDistanceMeters,
            trackPointCount: trackPointCount
        )

        Task.detached(priority: .background) {
            do {
                // Encode the struct via the Codable bridge so the
                // `expiresAt` Timestamp and the rejection dict serialise
                // cleanly, then merge a `serverTimestamp` sentinel for
                // the actual server-clock write time.
                let db = Firestore.firestore()
                let docRef = db.collection("users")
                    .document(uid)
                    .collection("walk_diagnostics")
                    .document(walkId)
                var payload = try Firestore.Encoder().encode(snapshot)
                // Strip any nil-valued keys our struct may have
                // produced (e.g. serverTimestamp pre-write) so the
                // server-clock sentinel below isn't overwritten by a
                // null and the Timestamp? doesn't land as NSNull.
                payload.removeValue(forKey: "serverTimestamp")
                payload["serverTimestamp"] = FieldValue.serverTimestamp()
                payload["isFinalWrite"] = isFinalWrite
                try await docRef.setData(payload, merge: true)
                print("[WalkDiagnostics] Shipped (final=\(isFinalWrite)) walkId=\(walkId)")
            } catch {
                // Non-fatal — diagnostics not landing must never break
                // the walk flow.
                print("[WalkDiagnostics] Failed to ship (final=\(isFinalWrite)): \(error)")
            }
        }
    }

    /// Background-during-walk snapshot writer. Wired to
    /// `UIApplication.didEnterBackgroundNotification` so we capture
    /// data even if the OS kills the app before stopTracking() runs.
    private func snapshotDiagnosticsOnBackground() {
        guard trackingState.isTracking else { return }
        shipDiagnosticsSnapshot(isFinalWrite: false)
    }

    // MARK: - Backgrounded-crash recovery (Android parity)

    /// True iff UserDefaults reports an in-flight walk that started
    /// less than 6 hours ago. Surface called by `WoofWalkApp` on
    /// cold-launch to decide whether to show the "Resume previous
    /// walk?" sheet.
    static func hasRecoverableInflightWalk() -> Bool {
        guard let _ = UserDefaults.standard.string(forKey: inflightWalkIdKey),
              let startedAt = UserDefaults.standard.object(forKey: inflightWalkStartedAtKey) as? Double else {
            return false
        }
        let ageSec = Date().timeIntervalSince1970 - startedAt
        return ageSec >= 0 && ageSec < (6 * 60 * 60)
    }

    /// Snapshot of the persisted in-flight walk for the recovery sheet.
    /// `Identifiable` conformance keyed on walkId so the SwiftUI
    /// `.sheet(item:)` modifier can drive the presentation.
    struct InflightWalkSnapshot: Identifiable {
        var id: String { walkId }
        let walkId: String
        let startedAt: Date
        let dogIds: [String]
        let mode: String
    }

    static func readInflightWalk() -> InflightWalkSnapshot? {
        guard let walkId = UserDefaults.standard.string(forKey: inflightWalkIdKey),
              let startedAtRaw = UserDefaults.standard.object(forKey: inflightWalkStartedAtKey) as? Double else {
            return nil
        }
        let dogIds: [String] = {
            guard let raw = UserDefaults.standard.string(forKey: inflightWalkDogIdsKey),
                  let data = raw.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String] else {
                return []
            }
            return parsed
        }()
        let mode = UserDefaults.standard.string(forKey: inflightWalkModeKey) ?? "personal"
        return InflightWalkSnapshot(
            walkId: walkId,
            startedAt: Date(timeIntervalSince1970: startedAtRaw),
            dogIds: dogIds,
            mode: mode
        )
    }

    /// Clear all in-flight markers. Called after the user declines the
    /// resume sheet (and we've finalised the orphaned walk), or after
    /// a successful resume hand-off.
    static func clearInflightWalkMarkers() {
        UserDefaults.standard.removeObject(forKey: inflightWalkIdKey)
        UserDefaults.standard.removeObject(forKey: inflightWalkStartedAtKey)
        UserDefaults.standard.removeObject(forKey: inflightWalkDogIdsKey)
        UserDefaults.standard.removeObject(forKey: inflightWalkModeKey)
    }

    /// Resume a walk after a backgrounded-crash. Re-arms the in-memory
    /// pipeline with the same sessionId so any track points written
    /// later land in the same Firestore doc. Mirrors Android
    /// `WalkBootReceiver.startForegroundService(EXTRA_AUTO_RESUME)`.
    ///
    /// Bumps `serviceKillCount` for the final diagnostics doc so we
    /// can count OS-kill events per walk.
    func resumeWalk(walkId: String) {
        if trackingState.isTracking {
            print("[WalkRecovery] Cannot resume — already tracking session \(trackingState.sessionId ?? "?")")
            return
        }
        print("[WalkRecovery] Resuming previous walk \(walkId) after OS kill")
        let snapshot = Self.readInflightWalk()
        startTracking(
            sessionId: walkId,
            dogIds: snapshot?.dogIds ?? [],
            mode: snapshot?.mode ?? "personal"
        )
        diagServiceKillCount += 1
    }

    /// Finalise an orphaned walk that the user chose NOT to resume.
    /// Writes a best-effort diagnostics doc marking the walk as
    /// `endReason: systemKilled` so we have telemetry on how often
    /// the OS is killing walks mid-flight.
    static func finaliseOrphanedWalk(_ snapshot: InflightWalkSnapshot) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[WalkRecovery] Cannot finalise orphan — no signed-in user")
            clearInflightWalkMarkers()
            return
        }
        let now = Date()
        let expiresAt = Timestamp(
            date: Date(timeIntervalSince1970: now.timeIntervalSince1970 + (90 * 24 * 60 * 60))
        )
        let payload: [String: Any] = [
            "walkId": snapshot.walkId,
            "userId": uid,
            "startedAtMs": Int64(snapshot.startedAt.timeIntervalSince1970 * 1000),
            "endedAtMs": Int64(now.timeIntervalSince1970 * 1000),
            "endReason": "systemKilled",
            "serviceKillCount": 1,
            "deviceManufacturer": "Apple",
            "deviceModel": UIDevice.current.model,
            "iosVersion": UIDevice.current.systemVersion,
            "expiresAt": expiresAt,
            "serverTimestamp": FieldValue.serverTimestamp(),
            "isFinalWrite": true,
        ]
        Task.detached(priority: .background) {
            do {
                let db = Firestore.firestore()
                try await db.collection("users")
                    .document(uid)
                    .collection("walk_diagnostics")
                    .document(snapshot.walkId)
                    .setData(payload, merge: true)
                print("[WalkRecovery] Finalised orphaned walk \(snapshot.walkId) as systemKilled")
            } catch {
                print("[WalkRecovery] Failed to finalise orphan: \(error)")
            }
            await MainActor.run { Self.clearInflightWalkMarkers() }
        }
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
