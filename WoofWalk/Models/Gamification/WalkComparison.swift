import Foundation

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
}
