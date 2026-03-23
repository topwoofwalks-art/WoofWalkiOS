import Foundation
import CoreLocation

/// Extended Kalman filter for GPS coordinate smoothing.
/// Tracks position and velocity in latitude / longitude space, fusing
/// incoming GPS fixes weighted by their reported accuracy.
final class KalmanFilter {

    // MARK: - State Vector

    /// Filtered latitude (degrees)
    private(set) var lat: Double = 0
    /// Filtered longitude (degrees)
    private(set) var lng: Double = 0
    /// Velocity component in latitude direction (degrees / second)
    private var velocityLat: Double = 0
    /// Velocity component in longitude direction (degrees / second)
    private var velocityLng: Double = 0
    /// Current estimated accuracy (meters)
    private(set) var accuracy: Double = 100
    /// Timestamp of the last processed fix (seconds since reference date)
    private var timestamp: TimeInterval = 0

    /// Process noise — controls how quickly the filter adapts.
    /// Higher values = more responsive but noisier output.
    private let processNoise: Double

    /// Whether the filter has received at least one measurement.
    private var isInitialised: Bool = false

    // MARK: - Initialisation

    /// - Parameter processNoise: Tuning knob for the process model.
    ///   Default `0.00001` matches Android's tighter ~1m walking uncertainty.
    init(processNoise: Double = 0.00001) {
        self.processNoise = processNoise
    }

    // MARK: - Public API

    /// Feed a raw GPS fix into the filter and receive the smoothed position.
    ///
    /// - Parameters:
    ///   - lat: Raw latitude in degrees.
    ///   - lng: Raw longitude in degrees.
    ///   - accuracy: Horizontal accuracy reported by the device (meters).
    ///   - timestamp: Fix timestamp (seconds since reference date, e.g. `Date().timeIntervalSinceReferenceDate`).
    /// - Returns: Smoothed `(lat, lng)` tuple in degrees.
    @discardableResult
    func process(lat: Double, lng: Double, accuracy: Double, timestamp: TimeInterval) -> (lat: Double, lng: Double) {
        let measuredAccuracy = max(accuracy, 1.0) // clamp to >= 1 m

        guard isInitialised else {
            // First measurement — initialise state directly.
            self.lat = lat
            self.lng = lng
            self.accuracy = measuredAccuracy
            self.timestamp = timestamp
            self.velocityLat = 0
            self.velocityLng = 0
            isInitialised = true
            return (lat, lng)
        }

        // Time delta
        let dt = timestamp - self.timestamp
        guard dt > 0 else {
            return (self.lat, self.lng)
        }
        self.timestamp = timestamp

        // --- Predict step ---
        // Propagate position using constant-velocity model.
        self.lat += velocityLat * dt
        self.lng += velocityLng * dt

        // Grow uncertainty: P = P + Q * dt
        // Convert process noise from degree^2/s to current dt.
        let processVariance = processNoise * dt * dt
        self.accuracy += processVariance

        // --- Update step ---
        // Kalman gain (scalar, treating lat and lng independently).
        let measurementVariance = metersToDegreesVariance(measuredAccuracy)
        let predictedVariance = metersToDegreesVariance(self.accuracy)
        let k = predictedVariance / (predictedVariance + measurementVariance)

        // Innovation (measurement residual).
        let innovationLat = lat - self.lat
        let innovationLng = lng - self.lng

        // Correct position.
        self.lat += k * innovationLat
        self.lng += k * innovationLng

        // Update velocity estimate from the innovation.
        self.velocityLat = k * (innovationLat / dt)
        self.velocityLng = k * (innovationLng / dt)

        // Update accuracy.
        self.accuracy = (1 - k) * self.accuracy
        // Blend with raw accuracy for stability.
        self.accuracy = max(self.accuracy, measuredAccuracy * 0.5)

        return (self.lat, self.lng)
    }

    /// Reset the filter to its uninitialised state.
    func reset() {
        lat = 0
        lng = 0
        velocityLat = 0
        velocityLng = 0
        accuracy = 100
        timestamp = 0
        isInitialised = false
    }

    // MARK: - Helpers

    /// Approximate conversion from meter-based accuracy to degree variance.
    /// 1 degree latitude ~ 111 320 m.
    private func metersToDegreesVariance(_ meters: Double) -> Double {
        let degreesPerMeter = 1.0 / 111_320.0
        return (meters * degreesPerMeter) * (meters * degreesPerMeter)
    }
}
