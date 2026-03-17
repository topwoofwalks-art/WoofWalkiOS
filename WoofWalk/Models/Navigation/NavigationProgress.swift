#if false
// DISABLED: References ambiguous RouteStep - duplicates handled in RoutingViewModel.swift
import Foundation

struct NavigationProgress: Codable, Equatable {
    let currentStepIndex: Int
    let distanceToNextStep: Double
    let totalDistanceRemaining: Double
    let totalTimeRemaining: Double
    let percentComplete: Double

    init(
        currentStepIndex: Int,
        distanceToNextStep: Double,
        totalDistanceRemaining: Double,
        totalTimeRemaining: Double,
        percentComplete: Double
    ) {
        self.currentStepIndex = currentStepIndex
        self.distanceToNextStep = distanceToNextStep
        self.totalDistanceRemaining = totalDistanceRemaining
        self.totalTimeRemaining = totalTimeRemaining
        self.percentComplete = percentComplete
    }

    static func calculate(
        currentStepIndex: Int,
        distanceToNextStep: Double,
        steps: [RouteStep],
        totalRouteDistance: Double
    ) -> NavigationProgress {
        var remainingDistance = distanceToNextStep
        var remainingTime = 0.0

        for i in currentStepIndex..<steps.count {
            remainingTime += steps[i].duration
            if i > currentStepIndex {
                remainingDistance += steps[i].distance
            }
        }

        let distanceTraveled = totalRouteDistance - remainingDistance
        let percentComplete = totalRouteDistance > 0 ? (distanceTraveled / totalRouteDistance) * 100 : 0

        return NavigationProgress(
            currentStepIndex: currentStepIndex,
            distanceToNextStep: distanceToNextStep,
            totalDistanceRemaining: remainingDistance,
            totalTimeRemaining: remainingTime,
            percentComplete: percentComplete
        )
    }

    var formattedDistanceRemaining: String {
        if totalDistanceRemaining < 1000 {
            return "\(Int(totalDistanceRemaining)) m"
        } else {
            return String(format: "%.1f km", totalDistanceRemaining / 1000)
        }
    }

    var formattedTimeRemaining: String {
        let seconds = Int(totalTimeRemaining)
        if seconds < 60 {
            return "< 1 min"
        } else if seconds < 3600 {
            return "\(seconds / 60) min"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours) hr \(mins) min" : "\(hours) hr"
        }
    }

    var formattedDistanceToNextStep: String {
        if distanceToNextStep < 1000 {
            return "\(Int(distanceToNextStep)) m"
        } else {
            return String(format: "%.1f km", distanceToNextStep / 1000)
        }
    }
}
#endif
