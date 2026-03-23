import Foundation
import CoreLocation

/// Chains multiple GPS quality filters to reject bad fixes and smooth
/// the remaining ones through a Kalman filter.
///
/// Pipeline order (matches Android WalkTrackingService):
/// 1. Accuracy gate  (adaptive: 100 m for first 60 s warmup, then 75 m)
/// 2. Bearing gate   (reject > 150-degree reversals within 5 s)
/// 3. Kalman filter  (smooth surviving points)
/// 4. Jitter gate    (min distance = max(2 m, accuracy × 0.1) + 3 s time gate)
/// 5. Speed gate     (reject > 4.2 m/s = ~15 km/h)
final class GPSFilterPipeline {

    // MARK: - Thresholds

    /// Maximum acceptable speed between consecutive points (m/s).
    /// 4.2 m/s ~ 15.12 km/h — a brisk run; anything faster is likely a GPS jump.
    private let maxSpeed: Double = 2.5  // 2.5 m/s = 9 km/h, max realistic walking+jogging
    /// Maximum acceptable bearing change to detect snap-back artefacts (degrees).
    private let maxBearingChange: Double = 150
    /// Minimum elapsed time before a bearing reversal is considered an outlier (seconds).
    private let bearingTimeWindow: TimeInterval = 5
    /// Warmup period during which accuracy threshold is relaxed (seconds).
    private let warmupDuration: TimeInterval = 60
    /// Accuracy threshold during warmup (meters).
    private let warmupAccuracyThreshold: CLLocationDistance = 50
    /// Accuracy threshold after warmup (meters).
    private let normalAccuracyThreshold: CLLocationDistance = 30
    /// Minimum time between accepted points for jitter gate (seconds).
    private let jitterTimeGate: TimeInterval = 3

    // MARK: - State

    private let kalman = KalmanFilter()
    private var previousLocation: CLLocation?
    private var previousBearing: Double?
    private var previousTimestamp: TimeInterval?

    /// Last accepted (post-jitter-gate) position and time.
    private var lastAcceptedLat: Double = 0
    private var lastAcceptedLng: Double = 0
    private var lastAcceptedTime: TimeInterval = 0

    /// Walk start time for adaptive accuracy warmup.
    private var walkStartTime: TimeInterval = 0
    private var isStarted: Bool = false

    /// Pedometer state for step-based validation.
    private var stepCountAtLastAccepted: Int = 0
    private var currentStepCount: Int = 0

    /// Compass heading for bearing validation.
    private var compassHeading: Double?

    /// Distance from last accepted point (available after process() returns non-nil).
    private(set) var lastAcceptedDistance: Double = 0

    // MARK: - Public API

    /// Update current step count from pedometer.
    func updateStepCount(_ steps: Int) {
        currentStepCount = steps
    }

    /// Update compass heading from CLLocationManager.
    func updateCompassHeading(_ heading: Double) {
        compassHeading = heading
    }

    /// Call once when the walk starts to begin the warmup timer.
    func start() {
        reset()
        walkStartTime = Date().timeIntervalSinceReferenceDate
        isStarted = true
    }

    /// Process a raw `CLLocation` through the pipeline.
    ///
    /// - Parameter location: The raw location from Core Location.
    /// - Returns: A smoothed `CLLocation` if the fix passes all gates, or `nil` if rejected.
    func process(_ location: CLLocation) -> CLLocation? {
        let ts = location.timestamp.timeIntervalSinceReferenceDate
        let accMeters = location.horizontalAccuracy

        // 1. Adaptive accuracy gate: relaxed to 100 m during first 60 s warmup, then 75 m
        guard accMeters >= 0 else { return nil }

        let warmupElapsed = isStarted ? (ts - walkStartTime) : warmupDuration + 1
        let accuracyThreshold = warmupElapsed < warmupDuration
            ? warmupAccuracyThreshold
            : normalAccuracyThreshold

        guard accMeters <= accuracyThreshold else {
            return nil
        }

        // 2. Bearing outlier detection: sudden 150°+ reversals in < 5 s = GPS multipath
        if let prev = previousLocation, let prevBearing = previousBearing, let prevTs = previousTimestamp {
            let dt = ts - prevTs
            if dt > 0, dt < bearingTimeWindow {
                let bearing = bearingBetween(from: prev.coordinate, to: location.coordinate)
                let delta = abs(angleDifference(bearing, prevBearing))
                if delta > maxBearingChange {
                    return nil
                }
            }
        }

        // Update bearing state
        if let prev = previousLocation {
            previousBearing = bearingBetween(from: prev.coordinate, to: location.coordinate)
        }
        previousTimestamp = ts
        previousLocation = location

        // 3. Kalman filter smoothing
        let smoothed = kalman.process(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            accuracy: accMeters,
            timestamp: ts
        )

        let filteredLat = smoothed.lat
        let filteredLng = smoothed.lng

        // 4. Jitter gate: prevent stationary GPS drift from accumulating phantom distance.
        //    Min distance = max(2 m, accuracy × 0.1); also require 3 s between accepted points.
        let minDistance = max(2.0, min(accMeters * accMeters / 100.0, 15.0))
        var distanceFromLast: Double = 0
        var timeDelta: TimeInterval = 0

        if lastAcceptedTime > 0 {
            timeDelta = ts - lastAcceptedTime
            distanceFromLast = Self.haversineDistance(
                lat1: lastAcceptedLat, lng1: lastAcceptedLng,
                lat2: filteredLat, lng2: filteredLng
            )
            if distanceFromLast < minDistance && timeDelta < jitterTimeGate {
                return nil
            }
        }

        // 5. Speed gate: reject > 15 km/h (4.2 m/s)
        if location.speed > 0 {
            if location.speed > maxSpeed && lastAcceptedTime > 0 {
                return nil
            }
        } else if distanceFromLast > 0, timeDelta > 0 {
            let calculatedSpeed = distanceFromLast / timeDelta
            if calculatedSpeed > maxSpeed && lastAcceptedTime > 0 {
                return nil
            }
        }

        // 6. Pedometer validation
        if lastAcceptedTime > 0 && timeDelta > 3 {
            let stepsSince = currentStepCount - stepCountAtLastAccepted
            let expectedDistance = Double(stepsSince) * 0.7

            // GPS claims much more than steps justify
            if stepsSince >= 2 && distanceFromLast > expectedDistance * 3.0 && distanceFromLast > 10 {
                return nil
            }

            // GPS claims movement but zero steps
            if distanceFromLast > 10 && stepsSince == 0 && timeDelta > 3 {
                return nil
            }
        }

        // 7. Compass heading validation
        if let heading = compassHeading, distanceFromLast > 5 {
            let gpsBearing = bearingBetween(
                from: CLLocationCoordinate2D(latitude: lastAcceptedLat, longitude: lastAcceptedLng),
                to: CLLocationCoordinate2D(latitude: filteredLat, longitude: filteredLng)
            )
            let bearingDiff = abs(angleDifference(gpsBearing, heading))
            if bearingDiff > 90 {
                return nil  // GPS says we moved sideways/backwards relative to compass
            }
        }

        // Update accepted point tracking
        lastAcceptedLat = filteredLat
        lastAcceptedLng = filteredLng
        lastAcceptedTime = ts
        lastAcceptedDistance = distanceFromLast
        stepCountAtLastAccepted = currentStepCount

        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: filteredLat, longitude: filteredLng),
            altitude: location.altitude,
            horizontalAccuracy: max(accMeters, kalman.accuracy),
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: location.speed,
            timestamp: location.timestamp
        )
    }

    /// Reset all internal state (e.g. at the start of a new walk).
    func reset() {
        kalman.reset()
        previousLocation = nil
        previousBearing = nil
        previousTimestamp = nil
        lastAcceptedLat = 0
        lastAcceptedLng = 0
        lastAcceptedTime = 0
        lastAcceptedDistance = 0
        walkStartTime = 0
        isStarted = false
        stepCountAtLastAccepted = 0
        currentStepCount = 0
        compassHeading = nil
    }

    // MARK: - Geometry Helpers

    /// Haversine distance in meters between two lat/lng points.
    static func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let earthRadius = 6_371_000.0 // meters
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    /// Bearing in degrees (0-360) from one coordinate to another.
    private func bearingBetween(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dLon = (to.longitude - from.longitude).degreesToRadians
        let lat1 = from.latitude.degreesToRadians
        let lat2 = to.latitude.degreesToRadians

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x).radiansToDegrees
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Signed shortest angular difference in degrees (range -180...180).
    private func angleDifference(_ a: Double, _ b: Double) -> Double {
        var diff = a - b
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        return diff
    }
}

// MARK: - Numeric Helpers
// degreesToRadians is defined in LivestockFieldRepository.swift

private extension Double {
    var radiansToDegrees: Double { self * 180 / .pi }
}
