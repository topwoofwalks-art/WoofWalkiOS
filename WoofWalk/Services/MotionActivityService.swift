import Foundation
import CoreMotion
import Combine

/// Provides real-time motion activity detection (stationary vs walking) and step counting
/// using CoreMotion's CMMotionActivityManager and CMPedometer.
///
/// Used by WalkTrackingService for fast (5s) auto-pause/resume instead of the slower
/// GPS-only approach (which had a 30s delay).
@MainActor
final class MotionActivityService: ObservableObject {

    static let shared = MotionActivityService()

    // MARK: - Published State

    /// `true` when the device detects no walking/running/cycling activity.
    @Published private(set) var isStationary: Bool = false

    /// Cumulative step count since `start()` was called.
    @Published private(set) var stepCount: Int = 0

    // MARK: - Private

    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    /// Timestamp when the current stationary period began (nil if moving).
    private var stationarySince: Date?

    /// Whether the service is currently active.
    private var isRunning = false

    /// Sessionkey for the current walk — used as the UserDefaults key for
    /// the persisted pedometer baseline (CMPedometer query start date).
    /// If the WalkTrackingService is recreated mid-walk (cold-launch from
    /// background while the foreground location task survived) we want
    /// the step count to resume from the original walk start, not reset
    /// to zero. Mirrors Android `SensorFusionManager.savePersistedBaseline`.
    private var sessionId: String?

    /// Timer that checks how long the user has been stationary.
    private var stationaryCheckTimer: Timer?

    /// How long the user must be stationary before `isStationary` flips to `true` (seconds).
    ///
    /// Bumped from 5 s to 170 s to mirror Android's auto-pause confirmation window.
    /// Combined with the ~10 s step-freshness gate that the location pipeline uses
    /// to confirm "really stopped", this lands at ~3 min total stationary before
    /// the walk auto-pauses — survives traffic lights, chats, poo-pickup.
    let stationaryThreshold: TimeInterval = 170.0

    /// Last time the pedometer reported a non-zero step delta.
    /// Used by the GPS pipeline + auto-resume watcher to confirm motion.
    @Published private(set) var lastStepIncrementAt: Date?

    /// Step count snapshot from the last pedometer callback (used to compute deltas).
    private var lastReportedStepCount: Int = 0

    private init() {}

    // MARK: - Public API

    /// Whether the user has authorised CoreMotion. `nil` while we haven't
    /// asked yet (first call to `start()` triggers the system prompt).
    @Published private(set) var motionAuthorisationStatus: CMAuthorizationStatus = .notDetermined

    func start(sessionId: String? = nil) {
        guard !isRunning else { return }
        isRunning = true
        isStationary = false
        stepCount = 0
        lastReportedStepCount = 0
        lastStepIncrementAt = nil
        stationarySince = nil
        self.sessionId = sessionId

        // Refresh auth status. The first startActivityUpdates / pedometer
        // call below triggers the system motion-permission prompt; if the
        // user denies, both services fail silently. We track the status
        // so PermissionsView can show a "denied" state instead of a
        // never-resolving spinner.
        motionAuthorisationStatus = CMMotionActivityManager.authorizationStatus()
        if motionAuthorisationStatus == .denied || motionAuthorisationStatus == .restricted {
            print("[MotionActivity] Authorisation denied/restricted — pedometer + activity off, walks won't count steps and motion-based auto-pause is disabled")
            // Skip startUpdates calls — they would silently fail and waste battery
            // firing into the void. The stationary-check timer still runs but will
            // never flip isStationary because there are no activity updates.
            startStationaryCheckTimer()
            print("[MotionActivity] Started in degraded mode (auth=\(motionAuthorisationStatus.rawValue))")
            return
        }

        startActivityUpdates()
        startPedometerUpdates()
        startStationaryCheckTimer()

        print("[MotionActivity] Started (auth=\(motionAuthorisationStatus.rawValue), session=\(sessionId ?? "ad-hoc"))")
    }

    /// Re-reads the current motion authorisation status. Call when
    /// returning from the Settings app so UI can refresh.
    func refreshAuthorisation() {
        motionAuthorisationStatus = CMMotionActivityManager.authorizationStatus()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        stationaryCheckTimer?.invalidate()
        stationaryCheckTimer = nil

        // Drop the persisted baseline before we forget the sessionId.
        clearPersistedBaseline()
        sessionId = nil

        isStationary = false
        stepCount = 0
        lastReportedStepCount = 0
        lastStepIncrementAt = nil
        stationarySince = nil

        print("[MotionActivity] Stopped")
    }

    /// Returns the number of steps taken in the last `seconds` seconds.
    /// Useful for validating GPS movement against actual steps.
    func recentSteps(inLast seconds: TimeInterval) async -> Int {
        guard CMPedometer.isStepCountingAvailable() else { return -1 }

        let now = Date()
        let from = now.addingTimeInterval(-seconds)

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: from, to: now) { data, error in
                if let error = error {
                    print("[MotionActivity] Pedometer query error: \(error.localizedDescription)")
                    continuation.resume(returning: -1)
                    return
                }
                continuation.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }

    // MARK: - Activity Updates

    private func startActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("[MotionActivity] Activity detection not available on this device")
            return
        }

        // Auth gate: silent failure if denied/restricted, plus battery cost.
        let auth = CMMotionActivityManager.authorizationStatus()
        guard auth != .denied, auth != .restricted else {
            print("[MotionActivity] Activity startUpdates skipped — auth=\(auth.rawValue)")
            return
        }

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }

            Task { @MainActor in
                self.handleActivityUpdate(activity)
            }
        }
    }

    private func handleActivityUpdate(_ activity: CMMotionActivity) {
        // Activity confidence must be at least medium to act on it
        guard activity.confidence.rawValue >= CMMotionActivityConfidence.medium.rawValue else { return }

        let isMoving = activity.walking || activity.running || activity.cycling

        if isMoving {
            // User is moving - clear stationary timer
            if stationarySince != nil {
                stationarySince = nil
                print("[MotionActivity] Movement detected, clearing stationary timer")
            }
            if isStationary {
                isStationary = false
                print("[MotionActivity] No longer stationary (activity: walking=\(activity.walking), running=\(activity.running))")
            }
        } else if activity.stationary {
            // User is stationary - start timing if not already
            if stationarySince == nil {
                stationarySince = Date()
                print("[MotionActivity] Stationary detected, starting timer")
            }
        }
    }

    // MARK: - Pedometer Updates

    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("[MotionActivity] Step counting not available on this device")
            return
        }

        // Auth gate: if denied/restricted, calling startUpdates will fail
        // silently and burn battery. Skip entirely.
        let auth = CMMotionActivityManager.authorizationStatus()
        guard auth != .denied, auth != .restricted else {
            print("[MotionActivity] Pedometer startUpdates skipped — auth=\(auth.rawValue)")
            return
        }

        // Resolve the baseline start date. If we have a sessionId AND a
        // persisted baseline for it, query from then so a mid-walk
        // service restart doesn't reset the cumulative count to zero.
        // Mirrors Android `SensorFusionManager.loadPersistedBaseline`.
        let baseline: Date = loadOrPersistBaseline(now: Date())

        pedometer.startUpdates(from: baseline) { [weak self] data, error in
            guard let self else { return }

            if let error = error {
                print("[MotionActivity] Pedometer error: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }
            let steps = data.numberOfSteps.intValue

            Task { @MainActor in
                if steps > self.lastReportedStepCount {
                    self.lastStepIncrementAt = Date()
                }
                self.lastReportedStepCount = steps
                self.stepCount = steps
            }
        }
    }

    /// Reads the persisted CMPedometer baseline for the current sessionId,
    /// or persists `now` as a fresh baseline. Without a sessionId we fall
    /// back to the in-memory baseline (no persistence, no restart resilience).
    private func loadOrPersistBaseline(now: Date) -> Date {
        guard let sid = sessionId else { return now }
        let key = "motionActivity.\(sid).pedometerBaseline"
        if let stored = UserDefaults.standard.object(forKey: key) as? Double, stored > 0 {
            print("[MotionActivity] Restored persisted pedometer baseline for session \(sid): \(stored)")
            return Date(timeIntervalSince1970: stored)
        }
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: key)
        return now
    }

    /// Clear the persisted baseline. Called from `stop()`.
    private func clearPersistedBaseline() {
        guard let sid = sessionId else { return }
        UserDefaults.standard.removeObject(forKey: "motionActivity.\(sid).pedometerBaseline")
    }

    // MARK: - Stationary Check Timer

    /// Periodically checks whether the stationary duration has exceeded the threshold.
    /// This decouples the threshold check from the (sometimes delayed) activity updates.
    private func startStationaryCheckTimer() {
        stationaryCheckTimer?.invalidate()
        stationaryCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.evaluateStationaryDuration()
            }
        }
    }

    private func evaluateStationaryDuration() {
        guard let since = stationarySince else { return }

        let elapsed = Date().timeIntervalSince(since)
        if elapsed >= stationaryThreshold && !isStationary {
            isStationary = true
            print("[MotionActivity] Stationary for \(String(format: "%.1f", elapsed))s - marking as stationary")
        }
    }
}
