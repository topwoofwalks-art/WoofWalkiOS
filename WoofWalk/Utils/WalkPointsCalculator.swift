import Foundation
import CoreLocation

struct TrackPoint {
    let lat: Double
    let lng: Double
    let t: TimeInterval // milliseconds since epoch
}

struct WalkValidationResult {
    let isValid: Bool
    let points: Int
    let basePoints: Int
    let bonusPoints: Int
    let penaltyPoints: Int
    let violations: [String]
    let reason: String
}

struct WalkPointsCalculator {
    // Base points
    static let basePoints = 10

    // Validation thresholds
    static let minDistanceMeters = 5.0
    static let minDurationSec: Int = 60
    static let minTrackPoints = 5
    static let maxSpeedMps = 8.0
    static let maxRealisticWalkSpeedMps = 2.5
    static let minPointSpacingSec: TimeInterval = 3.0
    static let maxWalksPerDay = 20
    static let suspiciousPatternThreshold = 0.9

    // Distance tier bonuses
    static let bonusLongWalk1km = 5
    static let bonusLongWalk3km = 15
    static let bonusLongWalk5km = 30
    static let bonusMarathon = 100

    // Streak bonus (fixed, not multiplicative)
    static let bonusDailyStreak = 2

    // Charity
    static let charityPointsPercent = 0.25

    struct PointsBreakdown {
        let basePoints: Int
        let distancePoints: Int
        let streakBonus: Int
        let charityPoints: Int
        let totalPoints: Int
        let totalWithCharity: Int
    }

    /// Full points calculation with validation and anti-gaming, matching Android logic exactly.
    static func calculatePoints(
        distanceMeters: Double,
        durationSec: Int,
        trackPoints: [TrackPoint],
        walksCompletedToday: Int,
        hasWalkedYesterday: Bool,
        charityEnabled: Bool = false
    ) -> WalkValidationResult {
        var violations: [String] = []
        var bonusPoints = 0
        var penaltyPoints = 0

        // --- Validation ---

        if distanceMeters < minDistanceMeters {
            violations.append("Distance too short: \(distanceMeters)m < \(minDistanceMeters)m")
        }

        if durationSec < minDurationSec {
            violations.append("Duration too short: \(durationSec)s < \(minDurationSec)s")
        }

        if trackPoints.count < minTrackPoints {
            violations.append("Too few track points: \(trackPoints.count) < \(minTrackPoints)")
        }

        if walksCompletedToday >= maxWalksPerDay {
            violations.append("Too many walks today: \(walksCompletedToday) >= \(maxWalksPerDay)")
            penaltyPoints += basePoints
        }

        // Average speed check
        let avgSpeed = durationSec > 0 ? distanceMeters / Double(durationSec) : 0.0

        if avgSpeed > maxSpeedMps {
            violations.append("Unrealistic speed: \(String(format: "%.2f", avgSpeed))m/s > \(maxSpeedMps)m/s (possible vehicle)")
            penaltyPoints += basePoints * 2
        }

        // Track point analysis
        if trackPoints.count >= 2 {
            let speedViolations = detectSpeedAnomalies(points: trackPoints)
            violations.append(contentsOf: speedViolations)
            if !speedViolations.isEmpty {
                penaltyPoints += 5
            }

            let patternScore = detectSuspiciousPatterns(points: trackPoints)
            if patternScore > suspiciousPatternThreshold {
                violations.append("Suspicious GPS pattern detected (score: \(String(format: "%.2f", patternScore)))")
                penaltyPoints += basePoints
            }

            let spacingViolations = detectTimingAnomalies(points: trackPoints)
            violations.append(contentsOf: spacingViolations)
            if !spacingViolations.isEmpty {
                penaltyPoints += 3
            }
        }

        // If walk is too short, return invalid with zero points
        if distanceMeters < minDistanceMeters || durationSec < minDurationSec {
            let reason = "Walk too short: \(String(format: "%.2f", distanceMeters / 1000.0))km in \(durationSec / 60)min (min: \(minDistanceMeters / 1000.0)km, \(minDurationSec / 60)min)"
            return WalkValidationResult(
                isValid: false,
                points: 0,
                basePoints: 0,
                bonusPoints: 0,
                penaltyPoints: 0,
                violations: violations,
                reason: reason
            )
        }

        // --- Distance tier bonuses (discrete, not per-km) ---
        let distanceKm = distanceMeters / 1000.0
        if distanceKm >= 42.195 {
            bonusPoints += bonusMarathon
        } else if distanceKm >= 5.0 {
            bonusPoints += bonusLongWalk5km
        } else if distanceKm >= 3.0 {
            bonusPoints += bonusLongWalk3km
        } else if distanceKm >= 1.0 {
            bonusPoints += bonusLongWalk1km
        }

        // --- Streak bonus: fixed +2 if walked yesterday and speed is realistic ---
        if hasWalkedYesterday && avgSpeed <= maxRealisticWalkSpeedMps {
            bonusPoints += bonusDailyStreak
        }

        let totalPoints = max(0, basePoints + bonusPoints - penaltyPoints)

        let isValid = violations.isEmpty || (violations.count == 1 && walksCompletedToday < maxWalksPerDay)

        var reason = "Walk completed: \(String(format: "%.2f", distanceKm))km in \(durationSec / 60)min"
        if bonusPoints > 0 { reason += " +\(bonusPoints) bonus" }
        if penaltyPoints > 0 { reason += " -\(penaltyPoints) penalty" }
        if !violations.isEmpty { reason += " (\(violations.count) issues)" }

        return WalkValidationResult(
            isValid: isValid,
            points: totalPoints,
            basePoints: basePoints,
            bonusPoints: bonusPoints,
            penaltyPoints: penaltyPoints,
            violations: violations,
            reason: reason
        )
    }

    /// Convenience method that returns a PointsBreakdown (preserves the charity calculation).
    static func calculatePointsBreakdown(
        distanceMeters: Double,
        durationSec: Int,
        trackPoints: [TrackPoint],
        walksCompletedToday: Int,
        hasWalkedYesterday: Bool,
        charityEnabled: Bool
    ) -> PointsBreakdown {
        let result = calculatePoints(
            distanceMeters: distanceMeters,
            durationSec: durationSec,
            trackPoints: trackPoints,
            walksCompletedToday: walksCompletedToday,
            hasWalkedYesterday: hasWalkedYesterday,
            charityEnabled: charityEnabled
        )

        let distancePoints = result.bonusPoints - (hasWalkedYesterday ? bonusDailyStreak : 0)
        let streakBonus = hasWalkedYesterday ? min(bonusDailyStreak, result.bonusPoints) : 0
        let charity = charityEnabled ? Int(Double(result.points) * charityPointsPercent) : 0

        return PointsBreakdown(
            basePoints: result.basePoints,
            distancePoints: max(0, distancePoints),
            streakBonus: streakBonus,
            charityPoints: charity,
            totalPoints: result.points,
            totalWithCharity: result.points + charity
        )
    }

    // MARK: - Anti-gaming detection (matches Android exactly)

    private static func detectSpeedAnomalies(points: [TrackPoint]) -> [String] {
        var violations: [String] = []
        var highSpeedCount = 0

        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]

            let distance = haversineDistance(lat1: p1.lat, lng1: p1.lng, lat2: p2.lat, lng2: p2.lng)
            let timeDiff = (p2.t - p1.t) / 1000.0

            if timeDiff > 0 {
                let speed = distance / timeDiff
                if speed > maxSpeedMps {
                    highSpeedCount += 1
                }
            }
        }

        if highSpeedCount > Int(Double(points.count) * 0.3) {
            violations.append("High speed detected in \(highSpeedCount)/\(points.count) segments")
        }

        return violations
    }

    private static func detectSuspiciousPatterns(points: [TrackPoint]) -> Double {
        if points.count < 10 { return 0.0 }

        var perfectlySpacedCount = 0
        var distances: [Double] = []

        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]
            let distance = haversineDistance(lat1: p1.lat, lng1: p1.lng, lat2: p2.lat, lng2: p2.lng)
            distances.append(distance)
        }

        if distances.count >= 3 {
            let avgDistance = distances.reduce(0, +) / Double(distances.count)
            let variance = distances.map { ($0 - avgDistance) * ($0 - avgDistance) }.reduce(0, +) / Double(distances.count)
            let stdDev = sqrt(variance)

            if stdDev < avgDistance * 0.1 && avgDistance > 0 {
                perfectlySpacedCount = distances.count
            }
        }

        var straightLineCount = 0
        for i in 0..<(points.count - 2) {
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[i + 2]

            let bearing1 = calculateBearing(lat1: p1.lat, lng1: p1.lng, lat2: p2.lat, lng2: p2.lng)
            let bearing2 = calculateBearing(lat1: p2.lat, lng1: p2.lng, lat2: p3.lat, lng2: p3.lng)

            let bearingDiff = abs(bearing1 - bearing2)

            if bearingDiff < 5.0 || bearingDiff > 355.0 {
                straightLineCount += 1
            }
        }

        let straightLineRatio = Double(straightLineCount) / Double(points.count - 2)
        let spacingRatio = Double(perfectlySpacedCount) / Double(distances.count)

        return straightLineRatio * 0.6 + spacingRatio * 0.4
    }

    private static func detectTimingAnomalies(points: [TrackPoint]) -> [String] {
        var violations: [String] = []
        var tooFrequentCount = 0

        for i in 0..<(points.count - 1) {
            let timeDiff = (points[i + 1].t - points[i].t) / 1000.0

            if timeDiff < minPointSpacingSec {
                tooFrequentCount += 1
            }
        }

        if tooFrequentCount > Int(Double(points.count) * 0.5) {
            violations.append("Points recorded too frequently (\(tooFrequentCount)/\(points.count) < \(Int(minPointSpacingSec))s apart)")
        }

        return violations
    }

    // MARK: - Geo utilities (matches Android haversine)

    private static func haversineDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLng = (lng2 - lng1) * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLng / 2) * sin(dLng / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    private static func calculateBearing(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let dLng = (lng2 - lng1) * .pi / 180.0
        let lat1Rad = lat1 * .pi / 180.0
        let lat2Rad = lat2 * .pi / 180.0

        let y = sin(dLng) * cos(lat2Rad)
        let x = cos(lat1Rad) * sin(lat2Rad) -
                sin(lat1Rad) * cos(lat2Rad) * cos(dLng)

        let bearing = atan2(y, x) * 180.0 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
