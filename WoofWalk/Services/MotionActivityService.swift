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

    /// Timer that checks how long the user has been stationary.
    private var stationaryCheckTimer: Timer?

    /// How long the user must be stationary before `isStationary` flips to `true` (seconds).
    let stationaryThreshold: TimeInterval = 5.0

    private init() {}

    // MARK: - Public API

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isStationary = false
        stepCount = 0
        stationarySince = nil

        startActivityUpdates()
        startPedometerUpdates()
        startStationaryCheckTimer()

        print("[MotionActivity] Started")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        stationaryCheckTimer?.invalidate()
        stationaryCheckTimer = nil

        isStationary = false
        stepCount = 0
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

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self else { return }

            if let error = error {
                print("[MotionActivity] Pedometer error: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }
            let steps = data.numberOfSteps.intValue

            Task { @MainActor in
                self.stepCount = steps
            }
        }
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
