import Foundation
import CoreLocation

enum NavGuidanceState: Equatable {
    case idle
    case active(ActiveGuidance)
    case offRoute(OffRouteGuidance)
    case completed
    case error(String)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var isOffRoute: Bool {
        if case .offRoute = self { return true }
        return false
    }

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

struct ActiveGuidance: Equatable {
    let currentInstruction: String
    let distanceToNextStepMeters: Double
    let currentStepIndex: Int
    let totalSteps: Int
    let routePolyline: [CLLocationCoordinate2D]
    let remainingDistanceMeters: Double
    let estimatedTimeRemainingSeconds: Int
    let isRerouting: Bool

    init(
        currentInstruction: String,
        distanceToNextStepMeters: Double,
        currentStepIndex: Int,
        totalSteps: Int,
        routePolyline: [CLLocationCoordinate2D] = [],
        remainingDistanceMeters: Double = 0.0,
        estimatedTimeRemainingSeconds: Int = 0,
        isRerouting: Bool = false
    ) {
        self.currentInstruction = currentInstruction
        self.distanceToNextStepMeters = distanceToNextStepMeters
        self.currentStepIndex = currentStepIndex
        self.totalSteps = totalSteps
        self.routePolyline = routePolyline
        self.remainingDistanceMeters = remainingDistanceMeters
        self.estimatedTimeRemainingSeconds = estimatedTimeRemainingSeconds
        self.isRerouting = isRerouting
    }

    var formattedDistanceToNextStep: String {
        if distanceToNextStepMeters < 1000 {
            return "\(Int(distanceToNextStepMeters)) m"
        } else {
            return String(format: "%.1f km", distanceToNextStepMeters / 1000)
        }
    }

    var formattedRemainingDistance: String {
        if remainingDistanceMeters < 1000 {
            return "\(Int(remainingDistanceMeters)) m"
        } else {
            return String(format: "%.1f km", remainingDistanceMeters / 1000)
        }
    }

    var formattedETA: String {
        if estimatedTimeRemainingSeconds < 60 {
            return "< 1 min"
        } else if estimatedTimeRemainingSeconds < 3600 {
            return "\(estimatedTimeRemainingSeconds / 60) min"
        } else {
            let hours = estimatedTimeRemainingSeconds / 3600
            let mins = (estimatedTimeRemainingSeconds % 3600) / 60
            return mins > 0 ? "\(hours) hr \(mins) min" : "\(hours) hr"
        }
    }

    var progressPercentage: Double {
        guard totalSteps > 0 else { return 0.0 }
        return (Double(currentStepIndex) / Double(totalSteps)) * 100.0
    }

    static func == (lhs: ActiveGuidance, rhs: ActiveGuidance) -> Bool {
        return lhs.currentInstruction == rhs.currentInstruction &&
               lhs.distanceToNextStepMeters == rhs.distanceToNextStepMeters &&
               lhs.currentStepIndex == rhs.currentStepIndex &&
               lhs.totalSteps == rhs.totalSteps &&
               lhs.remainingDistanceMeters == rhs.remainingDistanceMeters &&
               lhs.estimatedTimeRemainingSeconds == rhs.estimatedTimeRemainingSeconds &&
               lhs.isRerouting == rhs.isRerouting &&
               lhs.routePolyline.count == rhs.routePolyline.count
    }
}

struct OffRouteGuidance: Equatable {
    let distanceOffRoute: Double
    let lastKnownGuidance: ActiveGuidance

    init(
        distanceOffRoute: Double,
        lastKnownGuidance: ActiveGuidance
    ) {
        self.distanceOffRoute = distanceOffRoute
        self.lastKnownGuidance = lastKnownGuidance
    }

    var formattedDistanceOffRoute: String {
        if distanceOffRoute < 1000 {
            return "\(Int(distanceOffRoute)) m"
        } else {
            return String(format: "%.1f km", distanceOffRoute / 1000)
        }
    }
}
