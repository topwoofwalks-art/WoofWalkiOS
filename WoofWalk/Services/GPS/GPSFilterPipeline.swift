import Foundation
import CoreLocation

/// Permissive GPS pipeline: accept almost everything during recording,
/// apply Kalman filter for display smoothing only.
/// Heavy filtering is deferred to GpsPostProcessor after the walk ends.
///
/// During-walk gates (minimal):
/// 1. Reject truly invalid (negative accuracy or > 100 m)
/// 2. Reject hardware glitch teleportation (speed > 50 m/s)
/// 3. Minimum 1 s time gate to prevent flooding
/// 4. Kalman filter for display smoothing only
final class GPSFilterPipeline {

    // MARK: - State

    private let kalman = KalmanFilter()

    /// Last accepted position and time.
    private var lastAcceptedLat: Double = 0
    private var lastAcceptedLng: Double = 0
    private var lastAcceptedTime: TimeInterval = 0

    /// Distance from last accepted point (available after process() returns non-nil).
    private(set) var lastAcceptedDistance: Double = 0

    // MARK: - Public API

    /// Call once when the walk starts.
    func start() {
        reset()
    }

    /// Process a raw `CLLocation` through the permissive pipeline.
    ///
    /// - Parameter location: The raw location from Core Location.
    /// - Returns: A Kalman-smoothed `CLLocation` for display, or `nil` if rejected.
    func process(_ location: CLLocation) -> CLLocation? {
        let ts = location.timestamp.timeIntervalSinceReferenceDate
        let accMeters = location.horizontalAccuracy

        // 1. Only reject truly invalid
        guard accMeters >= 0, accMeters <= 100 else { return nil }

        // 2. Reject hardware glitch teleportation
        if location.speed > 50 { return nil }

        // 3. Minimum time gate (1 point per second)
        if lastAcceptedTime > 0, (ts - lastAcceptedTime) < 0.9 { return nil }

        // 4. Kalman filter for display smoothing only
        let smoothed = kalman.process(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            accuracy: accMeters,
            timestamp: ts
        )

        // 5. Calculate distance for live stats
        var distanceFromLast: Double = 0
        if lastAcceptedTime > 0 {
            distanceFromLast = Self.haversineDistance(
                lat1: lastAcceptedLat, lng1: lastAcceptedLng,
                lat2: smoothed.lat, lng2: smoothed.lng
            )
        }

        lastAcceptedLat = smoothed.lat
        lastAcceptedLng = smoothed.lng
        lastAcceptedTime = ts
        lastAcceptedDistance = distanceFromLast

        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: smoothed.lat, longitude: smoothed.lng),
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
        lastAcceptedLat = 0
        lastAcceptedLng = 0
        lastAcceptedTime = 0
        lastAcceptedDistance = 0
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
}
