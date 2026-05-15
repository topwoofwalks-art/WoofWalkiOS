import Foundation
import CoreLocation

struct WalkComparison: Codable {
    var plannedDistanceKm: Double
    var actualDistanceKm: Double
    var distanceDiffPercent: Double
    var plannedDurationMin: Double
    var actualDurationMin: Double
    var durationDiffPercent: Double
    var routeAdherencePercent: Double
    var poisPlanned: Int
    var poisVisited: Int
    var avgDeviationMeters: Double
    var completedFaster: Bool
    var completedShorter: Bool
    var hasPlannedRoute: Bool

    var isDistanceMatch: Bool { abs(distanceDiffPercent) < 10.0 }
    var isDurationMatch: Bool { abs(durationDiffPercent) < 10.0 }
    var overallMatch: Double {
        let factors = [routeAdherencePercent, isDistanceMatch ? 100.0 : max(0, 100.0 - abs(distanceDiffPercent)), isDurationMatch ? 100.0 : max(0, 100.0 - abs(durationDiffPercent))]
        return factors.reduce(0, +) / Double(factors.count)
    }

    // default init
    init(plannedDistanceKm: Double = 0, actualDistanceKm: Double = 0, distanceDiffPercent: Double = 0, plannedDurationMin: Double = 0, actualDurationMin: Double = 0, durationDiffPercent: Double = 0, routeAdherencePercent: Double = 0, poisPlanned: Int = 0, poisVisited: Int = 0, avgDeviationMeters: Double = 0, completedFaster: Bool = false, completedShorter: Bool = false, hasPlannedRoute: Bool = false) {
        self.plannedDistanceKm = plannedDistanceKm; self.actualDistanceKm = actualDistanceKm; self.distanceDiffPercent = distanceDiffPercent; self.plannedDurationMin = plannedDurationMin; self.actualDurationMin = actualDurationMin; self.durationDiffPercent = durationDiffPercent; self.routeAdherencePercent = routeAdherencePercent; self.poisPlanned = poisPlanned; self.poisVisited = poisVisited; self.avgDeviationMeters = avgDeviationMeters; self.completedFaster = completedFaster; self.completedShorter = completedShorter; self.hasPlannedRoute = hasPlannedRoute
    }

    // MARK: - Build from planned + actual

    /// Build a comparison from a `PlannedWalk` and the actual recorded
    /// track. Returns nil when the planned walk has no usable route — the
    /// caller then persists the walk without a comparison so the recap
    /// just shows actual stats.
    ///
    /// `routeAdherencePercent` is computed as the share of actual-track
    /// points within `adherenceRadiusMeters` of any planned-route segment.
    /// 30 m matches the Android default in
    /// `RouteAdherenceCalculator.kt`; tweak per-call if needed.
    static func build(
        planned: PlannedWalk,
        actualDistanceMeters: Double,
        actualDurationSec: Int,
        actualTrack: [CLLocationCoordinate2D],
        poisVisited: Int = 0,
        adherenceRadiusMeters: Double = 30.0
    ) -> WalkComparison? {
        let plannedDistKm = planned.estimatedDistanceMeters / 1000.0
        let plannedDurMin = Double(planned.estimatedDurationSec) / 60.0
        guard plannedDistKm > 0 || plannedDurMin > 0 else { return nil }

        let actualDistKm = actualDistanceMeters / 1000.0
        let actualDurMin = Double(actualDurationSec) / 60.0

        let distDiffPct: Double = {
            guard plannedDistKm > 0 else { return 0 }
            return ((actualDistKm - plannedDistKm) / plannedDistKm) * 100.0
        }()
        let durDiffPct: Double = {
            guard plannedDurMin > 0 else { return 0 }
            return ((actualDurMin - plannedDurMin) / plannedDurMin) * 100.0
        }()

        let plannedCoords = planned.routePolyline.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let adherence = computeAdherence(
            actual: actualTrack,
            planned: plannedCoords,
            radiusMeters: adherenceRadiusMeters
        )

        return WalkComparison(
            plannedDistanceKm: plannedDistKm,
            actualDistanceKm: actualDistKm,
            distanceDiffPercent: distDiffPct,
            plannedDurationMin: plannedDurMin,
            actualDurationMin: actualDurMin,
            durationDiffPercent: durDiffPct,
            routeAdherencePercent: adherence.percent,
            poisPlanned: planned.poiIds.count,
            poisVisited: poisVisited,
            avgDeviationMeters: adherence.avgDeviation,
            completedFaster: actualDurMin > 0 && plannedDurMin > 0 && actualDurMin < plannedDurMin,
            completedShorter: actualDistKm > 0 && plannedDistKm > 0 && actualDistKm < plannedDistKm,
            hasPlannedRoute: !plannedCoords.isEmpty
        )
    }

    /// % of actual-track points within radius of any planned point + the
    /// mean point-to-route deviation in metres. Both 0 when either side is
    /// empty — caller treats that as "no meaningful adherence".
    private static func computeAdherence(
        actual: [CLLocationCoordinate2D],
        planned: [CLLocationCoordinate2D],
        radiusMeters: Double
    ) -> (percent: Double, avgDeviation: Double) {
        guard !actual.isEmpty, !planned.isEmpty else { return (0, 0) }
        let plannedLocs = planned.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var inRange = 0
        var totalDeviation: Double = 0
        for coord in actual {
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            var minDist = Double.greatestFiniteMagnitude
            for p in plannedLocs {
                let d = loc.distance(from: p)
                if d < minDist { minDist = d }
            }
            totalDeviation += minDist
            if minDist <= radiusMeters { inRange += 1 }
        }
        let pct = (Double(inRange) / Double(actual.count)) * 100.0
        let avgDev = totalDeviation / Double(actual.count)
        return (pct, avgDev)
    }
}
