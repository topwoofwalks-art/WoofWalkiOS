import Foundation
import CoreLocation

/// Chains multiple GPS quality filters to reject bad fixes and smooth
/// the remaining ones through a Kalman filter.
///
/// Pipeline order:
/// 1. Accuracy gate  (reject > 50 m)
/// 2. Speed gate     (reject > 4.2 m/s = ~15 km/h)
/// 3. Bearing gate   (reject > 90-degree reversals within 5 s)
/// 4. Kalman filter  (smooth surviving points)
final class GPSFilterPipeline {

    // MARK: - Thresholds

    /// Maximum acceptable horizontal accuracy (meters).
    private let maxAccuracy: CLLocationDistance = 50
    /// Maximum acceptable speed between consecutive points (m/s).
    /// 4.2 m/s ~ 15.12 km/h — a brisk run; anything faster is likely a GPS jump.
    private let maxSpeed: Double = 4.2
    /// Maximum acceptable bearing change to detect snap-back artefacts (degrees).
    private let maxBearingChange: Double = 90
    /// Minimum elapsed time before a bearing reversal is considered an outlier (seconds).
    private let bearingTimeWindow: TimeInterval = 5

    // MARK: - State

    private let kalman = KalmanFilter()
    private var previousLocation: CLLocation?
    private var previousBearing: Double?
    private var previousTimestamp: TimeInterval?

    // MARK: - Public API

    /// Process a raw `CLLocation` through the pipeline.
    ///
    /// - Parameter location: The raw location from Core Location.
    /// - Returns: A smoothed `CLLocation` if the fix passes all gates, or `nil` if rejected.
    func process(_ location: CLLocation) -> CLLocation? {
        // 1. Accuracy gate
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxAccuracy else {
            return nil
        }

        let ts = location.timestamp.timeIntervalSinceReferenceDate

        // 2. Speed gate
        if let prev = previousLocation {
            let dt = location.timestamp.timeIntervalSince(prev.timestamp)
            if dt > 0 {
                let speed = location.distance(from: prev) / dt
                if speed > maxSpeed {
                    return nil
                }
            }
        }

        // 3. Bearing outlier detection
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

        // 4. Kalman filter smoothing
        let smoothed = kalman.process(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: ts
        )

        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: smoothed.lat, longitude: smoothed.lng),
            altitude: location.altitude,
            horizontalAccuracy: max(location.horizontalAccuracy, kalman.accuracy),
            verticalAccuracy: location.verticalAccuracy,
            timestamp: location.timestamp
        )
    }

    /// Reset all internal state (e.g. at the start of a new walk).
    func reset() {
        kalman.reset()
        previousLocation = nil
        previousBearing = nil
        previousTimestamp = nil
    }

    // MARK: - Geometry Helpers

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
