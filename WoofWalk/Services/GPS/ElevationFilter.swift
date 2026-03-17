import Foundation
import CoreLocation

/// 5-point sliding-window median filter for altitude smoothing.
///
/// GPS altitude readings are notoriously noisy. A median filter is more
/// robust to outliers than a moving average while preserving genuine
/// elevation changes.
final class ElevationFilter {

    /// Size of the sliding window.
    private let windowSize: Int
    /// Ring buffer of recent altitude samples.
    private var buffer: [Double] = []

    /// - Parameter windowSize: Number of samples in the sliding window. Defaults to 5.
    init(windowSize: Int = 5) {
        self.windowSize = max(1, windowSize)
    }

    /// Feed a raw altitude value and receive the median-smoothed result.
    ///
    /// - Parameter altitude: Raw altitude in meters (from `CLLocation.altitude`).
    /// - Returns: Median of the most recent `windowSize` altitude values.
    func process(altitude: Double) -> Double {
        buffer.append(altitude)
        if buffer.count > windowSize {
            buffer.removeFirst()
        }

        return median(of: buffer)
    }

    /// Reset the filter, clearing all buffered samples.
    func reset() {
        buffer.removeAll()
    }

    // MARK: - Helpers

    /// Compute the median of an array of Doubles.
    private func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
}
