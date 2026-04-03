import Foundation
import CoreLocation

/// Generates interpolated GPS points during signal gaps using pedometer step count
/// and compass heading. When GPS drops out under tree cover, this fills the gap
/// with estimated positions instead of drawing a straight line.
///
/// Algorithm:
/// 1. Detect gap: no GPS fix for > gpsGapThreshold (3 seconds)
/// 2. Use step count delta x stride length for distance walked during gap
/// 3. Use compass heading samples to determine direction of travel
/// 4. Generate intermediate points along the walked path
/// 5. Warp the dead-reckoned segment so its endpoint matches the GPS return fix
///    (endpoint anchoring reduces cumulative compass drift)
///
/// All data stays on-device. Dead-reckoned points are stored as regular
/// track points and flow through the normal post-processing pipeline.
struct DeadReckoningManager {

    struct DeadReckonedPoint {
        let latitude: Double
        let longitude: Double
        let timestamp: TimeInterval

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    struct HeadingSample {
        let timestamp: TimeInterval  // timeIntervalSince1970
        let headingDegrees: Double
    }

    // MARK: - Constants

    /// Minimum gap duration to trigger dead reckoning (3 seconds)
    static let gpsGapThreshold: TimeInterval = 3.0

    /// Average walking stride length in meters
    static let strideLengthMeters: Double = 0.7

    /// Minimum steps to generate dead-reckoned points
    static let minStepsForDR: Int = 3

    /// Generate one DR point every N steps
    static let stepsPerPoint: Int = 2

    /// Maximum interpolated points per single gap
    static let maxDRPoints: Int = 100

    // MARK: - Public API

    /// Generate interpolated points to fill a GPS gap.
    ///
    /// - Parameters:
    ///   - startCoord: Last accepted GPS coordinate before the gap
    ///   - startTime: Timestamp of last accepted GPS fix (timeIntervalSince1970)
    ///   - endCoord: GPS coordinate when signal returned
    ///   - endTime: Timestamp of GPS return fix (timeIntervalSince1970)
    ///   - stepsDuringGap: Number of steps taken during the gap
    ///   - headingSamples: Timestamped compass heading samples collected during the gap
    /// - Returns: List of interpolated points (excluding start and end)
    /// - Parameter strideLengthMeters: Calibrated stride length. Defaults to 0.7m if not calibrated.
    func interpolateGap(
        startCoord: CLLocationCoordinate2D,
        startTime: TimeInterval,
        endCoord: CLLocationCoordinate2D,
        endTime: TimeInterval,
        stepsDuringGap: Int,
        headingSamples: [HeadingSample],
        strideLengthMeters: Double = strideLengthMeters
    ) -> [DeadReckonedPoint] {
        guard stepsDuringGap >= Self.minStepsForDR else {
            print("[DeadReckoning] Skipped: only \(stepsDuringGap) steps (min \(Self.minStepsForDR))")
            return []
        }

        guard !headingSamples.isEmpty else {
            print("[DeadReckoning] Skipped: no compass heading samples")
            return []
        }

        let totalDistance = Double(stepsDuringGap) * strideLengthMeters
        let gapDuration = endTime - startTime

        // Sanity check: if DR distance is wildly different from GPS straight-line, skip
        let gpsDistance = Self.haversine(startCoord, endCoord)
        if totalDistance > gpsDistance * 5.0 && gpsDistance > 5.0 {
            print("[DeadReckoning] Skipped: DR distance (\(Int(totalDistance))m) >> GPS distance (\(Int(gpsDistance))m)")
            return []
        }

        let numPoints = min(max(stepsDuringGap / Self.stepsPerPoint, 1), Self.maxDRPoints)
        let distancePerSegment = totalDistance / Double(numPoints + 1)

        print("[DeadReckoning] \(stepsDuringGap) steps, \(Int(totalDistance))m, \(numPoints) points, \(headingSamples.count) heading samples, gap=\(String(format: "%.1f", gapDuration))s")

        // Build the raw dead-reckoned path using compass headings
        var rawPoints: [DeadReckonedPoint] = []
        var currentLat = startCoord.latitude
        var currentLng = startCoord.longitude

        for i in 1...numPoints {
            let fraction = Double(i) / Double(numPoints + 1)
            let pointTime = startTime + gapDuration * fraction

            let heading = headingAtTime(pointTime, samples: headingSamples)
            let (newLat, newLng) = moveAlongBearing(lat: currentLat, lng: currentLng, bearingDeg: heading, distanceMeters: distancePerSegment)

            rawPoints.append(DeadReckonedPoint(latitude: newLat, longitude: newLng, timestamp: pointTime))
            currentLat = newLat
            currentLng = newLng
        }

        // Endpoint anchoring: warp the path so it ends at the actual GPS return point
        return anchorToEndpoint(rawPoints, endLat: endCoord.latitude, endLng: endCoord.longitude)
    }

    // MARK: - Private Helpers

    private func headingAtTime(_ time: TimeInterval, samples: [HeadingSample]) -> Double {
        guard samples.count > 1 else { return samples[0].headingDegrees }

        let before = samples.last(where: { $0.timestamp <= time }) ?? samples.first!
        let after = samples.first(where: { $0.timestamp > time }) ?? samples.last!

        guard before.timestamp != after.timestamp else { return before.headingDegrees }

        let fraction = (time - before.timestamp) / (after.timestamp - before.timestamp)
        return interpolateHeading(before.headingDegrees, after.headingDegrees, fraction: fraction)
    }

    private func interpolateHeading(_ h1: Double, _ h2: Double, fraction: Double) -> Double {
        var diff = h2 - h1
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        var result = h1 + diff * fraction
        if result < 0 { result += 360 }
        if result >= 360 { result -= 360 }
        return result
    }

    private func moveAlongBearing(lat: Double, lng: Double, bearingDeg: Double, distanceMeters: Double) -> (Double, Double) {
        let R = 6371000.0
        let d = distanceMeters / R
        let brng = bearingDeg * .pi / 180
        let lat1 = lat * .pi / 180
        let lng1 = lng * .pi / 180

        let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng))
        let lng2 = lng1 + atan2(sin(brng) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2))

        return (lat2 * 180 / .pi, lng2 * 180 / .pi)
    }

    private func anchorToEndpoint(_ rawPoints: [DeadReckonedPoint], endLat: Double, endLng: Double) -> [DeadReckonedPoint] {
        guard !rawPoints.isEmpty else { return rawPoints }

        let drEndLat = rawPoints.last!.latitude
        let drEndLng = rawPoints.last!.longitude

        let errorLat = endLat - drEndLat
        let errorLng = endLng - drEndLng

        return rawPoints.enumerated().map { index, point in
            let fraction = Double(index + 1) / Double(rawPoints.count + 1)
            return DeadReckonedPoint(
                latitude: point.latitude + errorLat * fraction,
                longitude: point.longitude + errorLng * fraction,
                timestamp: point.timestamp
            )
        }
    }

    // MARK: - Geometry

    static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let sinLat = sin(dLat / 2)
        let sinLng = sin(dLng / 2)
        let h = sinLat * sinLat + cos(a.latitude * .pi / 180) * cos(b.latitude * .pi / 180) * sinLng * sinLng
        return R * 2 * atan2(sqrt(h), sqrt(1 - h))
    }
}
