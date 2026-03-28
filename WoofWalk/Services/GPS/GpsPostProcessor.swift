import Foundation
import CoreLocation

/// Post-processes a raw GPS trace after walk completion.
/// Pipeline: Speed filter -> Savitzky-Golay smooth -> MAD outlier removal -> Douglas-Peucker simplification
struct GpsPostProcessor {

    struct RawPoint {
        let coordinate: CLLocationCoordinate2D
        let timestamp: TimeInterval
        let accuracy: Double
    }

    struct ProcessedTrace {
        let points: [CLLocationCoordinate2D]
        let distanceMeters: Double
        let pointsRemoved: Int
        let originalCount: Int
    }

    static func process(_ rawPoints: [RawPoint]) -> ProcessedTrace {
        guard rawPoints.count >= 3 else {
            let pts = rawPoints.map { $0.coordinate }
            return ProcessedTrace(points: pts, distanceMeters: totalDistance(pts), pointsRemoved: 0, originalCount: rawPoints.count)
        }

        let originalCount = rawPoints.count

        // Pass 1: Speed filter (>18 km/h = 5 m/s)
        let speedFiltered = filterBySpeed(rawPoints, maxSpeedMps: 5.0)

        // Pass 2: Savitzky-Golay smoothing (window=5, degree=2) - tighter preserves corners
        let smoothed = savitzkyGolaySmooth(speedFiltered, windowSize: 5)

        // Pass 3: MAD-based outlier removal
        let outlierFree = removeOutliersByMAD(smoothed, threshold: 3.0)

        // Pass 4: Douglas-Peucker simplification (epsilon=1m) - keep more detail
        let simplified = douglasPeucker(outlierFree, epsilonMeters: 1.0)

        let distance = totalDistance(simplified)
        return ProcessedTrace(points: simplified, distanceMeters: distance, pointsRemoved: originalCount - simplified.count, originalCount: originalCount)
    }

    // MARK: - Pass 1: Speed Filter

    private static func filterBySpeed(_ points: [RawPoint], maxSpeedMps: Double) -> [RawPoint] {
        guard points.count >= 2 else { return points }
        var result = [points[0]]

        for i in 1..<points.count {
            let prev = result.last!
            let curr = points[i]
            let dt = curr.timestamp - prev.timestamp
            guard dt > 0 else { continue }

            let dist = haversine(prev.coordinate, curr.coordinate)
            let speed = dist / dt

            if speed <= maxSpeedMps {
                result.append(curr)
            }
        }
        return result
    }

    // MARK: - Pass 2: Savitzky-Golay Smoothing

    private static func savitzkyGolaySmooth(_ points: [RawPoint], windowSize: Int) -> [CLLocationCoordinate2D] {
        guard points.count >= windowSize else {
            return points.map { $0.coordinate }
        }

        // Window=7, degree=2 coefficients: [-2, 3, 6, 7, 6, 3, -2] / 21
        let coefficients: [Double] = [-2, 3, 6, 7, 6, 3, -2].map { $0 / 21.0 }
        let halfWindow = windowSize / 2

        let lats = points.map { $0.coordinate.latitude }
        let lngs = points.map { $0.coordinate.longitude }

        var smoothedLats = lats
        var smoothedLngs = lngs

        for i in halfWindow..<(points.count - halfWindow) {
            var sumLat = 0.0, sumLng = 0.0
            for j in 0..<coefficients.count {
                let idx = i - halfWindow + j
                sumLat += coefficients[j] * lats[idx]
                sumLng += coefficients[j] * lngs[idx]
            }
            smoothedLats[i] = sumLat
            smoothedLngs[i] = sumLng
        }

        return (0..<points.count).map {
            CLLocationCoordinate2D(latitude: smoothedLats[$0], longitude: smoothedLngs[$0])
        }
    }

    // MARK: - Pass 3: MAD Outlier Removal

    private static func removeOutliersByMAD(_ points: [CLLocationCoordinate2D], threshold: Double) -> [CLLocationCoordinate2D] {
        guard points.count >= 5 else { return points }

        var distances: [Double] = []
        for i in 1..<points.count {
            distances.append(haversine(points[i-1], points[i]))
        }

        let sorted = distances.sorted()
        let median = sorted[sorted.count / 2]
        let deviations = distances.map { abs($0 - median) }.sorted()
        let mad = deviations[deviations.count / 2] * 1.4826

        guard mad > 0.001 else { return points }

        var result = [points[0]]
        for i in 1..<points.count {
            if abs(distances[i-1] - median) <= threshold * mad {
                result.append(points[i])
            }
        }
        if result.last?.latitude != points.last?.latitude {
            result.append(points.last!)
        }
        return result
    }

    // MARK: - Pass 4: Douglas-Peucker

    private static func douglasPeucker(_ points: [CLLocationCoordinate2D], epsilonMeters: Double) -> [CLLocationCoordinate2D] {
        guard points.count >= 3 else { return points }

        var maxDist = 0.0
        var maxIdx = 0

        for i in 1..<(points.count - 1) {
            let dist = perpendicularDistance(points[i], lineStart: points.first!, lineEnd: points.last!)
            if dist > maxDist {
                maxDist = dist
                maxIdx = i
            }
        }

        if maxDist > epsilonMeters {
            let left = douglasPeucker(Array(points[0...maxIdx]), epsilonMeters: epsilonMeters)
            let right = douglasPeucker(Array(points[maxIdx...]), epsilonMeters: epsilonMeters)
            return Array(left.dropLast()) + right
        } else {
            return [points.first!, points.last!]
        }
    }

    private static func perpendicularDistance(_ point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let lineLen = haversine(lineStart, lineEnd)
        guard lineLen > 0 else { return haversine(point, lineStart) }

        let dx = lineEnd.latitude - lineStart.latitude
        let dy = lineEnd.longitude - lineStart.longitude
        let px = point.latitude - lineStart.latitude
        let py = point.longitude - lineStart.longitude

        var t = (px * dx + py * dy) / (dx * dx + dy * dy)
        t = max(0, min(1, t))

        let projLat = lineStart.latitude + t * dx
        let projLng = lineStart.longitude + t * dy

        return haversine(point, CLLocationCoordinate2D(latitude: projLat, longitude: projLng))
    }

    // MARK: - Utilities

    static func totalDistance(_ points: [CLLocationCoordinate2D]) -> Double {
        var total = 0.0
        for i in 1..<points.count {
            total += haversine(points[i-1], points[i])
        }
        return total
    }

    private static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let sinLat = sin(dLat / 2)
        let sinLng = sin(dLng / 2)
        let h = sinLat * sinLat + cos(a.latitude * .pi / 180) * cos(b.latitude * .pi / 180) * sinLng * sinLng
        return R * 2 * atan2(sqrt(h), sqrt(1 - h))
    }
}
