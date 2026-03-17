#if false
// DISABLED: References ambiguous Route/RouteStep - duplicates handled in RoutingViewModel.swift
import Foundation
import CoreLocation
import Combine

@MainActor
class NavigationManager: ObservableObject {
    @Published private(set) var guidanceState: NavGuidanceState = .idle
    @Published private(set) var navigationProgress: NavigationProgress?

    private var currentSteps: [RouteStep] = []
    private var currentStepIndex: Int = 0
    private var routePolylinePoints: [CLLocationCoordinate2D] = []
    private var origin: CLLocationCoordinate2D?
    private var destination: CLLocationCoordinate2D?
    private var isRerouting: Bool = false
    private var totalRouteDistance: Double = 0

    func startGuidance(
        route: Route,
        userLocation: CLLocationCoordinate2D
    ) {
        currentSteps = route.allSteps
        currentStepIndex = 0
        routePolylinePoints = route.decodedPolyline
        totalRouteDistance = route.totalDistance

        origin = userLocation
        destination = routePolylinePoints.last

        guard !currentSteps.isEmpty else {
            guidanceState = .error("No navigation steps available")
            return
        }

        let firstStep = currentSteps[0]
        let distanceToEnd = NavigationLogic.calculateDistance(
            from: userLocation,
            to: firstStep.endLocation
        )

        let (remainingDist, remainingTime) = NavigationLogic.calculateRemainingStats(
            currentStepIndex: currentStepIndex,
            steps: currentSteps
        )

        navigationProgress = NavigationProgress.calculate(
            currentStepIndex: currentStepIndex,
            distanceToNextStep: distanceToEnd,
            steps: currentSteps,
            totalRouteDistance: totalRouteDistance
        )

        guidanceState = .active(
            ActiveGuidance(
                currentInstruction: NavigationLogic.cleanHtmlInstruction(firstStep.instruction),
                distanceToNextStepMeters: distanceToEnd,
                currentStepIndex: currentStepIndex,
                totalSteps: currentSteps.count,
                routePolyline: routePolylinePoints,
                remainingDistanceMeters: remainingDist,
                estimatedTimeRemainingSeconds: remainingTime,
                isRerouting: false
            )
        )

        print("[NavigationManager] Guidance started: \(currentSteps.count) steps")
    }

    func trackProgress(userLocation: CLLocationCoordinate2D) {
        guard case .active(let activeGuidance) = guidanceState else { return }
        guard !isRerouting else { return }

        let distanceToPolyline = NavigationLogic.calculateDistanceToPolyline(
            point: userLocation,
            polyline: routePolylinePoints
        )

        if distanceToPolyline > NavigationLogic.offRouteThresholdMeters {
            handleOffRoute(userLocation: userLocation, activeGuidance: activeGuidance)
            return
        }

        if currentStepIndex >= currentSteps.count {
            guidanceState = .completed
            print("[NavigationManager] Guidance completed")
            return
        }

        let currentStep = currentSteps[currentStepIndex]
        let distanceToStepEnd = NavigationLogic.calculateDistance(
            from: userLocation,
            to: currentStep.endLocation
        )

        if NavigationLogic.shouldAdvanceToNextStep(
            userLocation: userLocation,
            stepEndLocation: currentStep.endLocation
        ) {
            advanceToNextStep(userLocation: userLocation)
        } else {
            let (remainingDist, remainingTime) = NavigationLogic.calculateRemainingStats(
                currentStepIndex: currentStepIndex,
                steps: currentSteps
            )

            navigationProgress = NavigationProgress.calculate(
                currentStepIndex: currentStepIndex,
                distanceToNextStep: distanceToStepEnd,
                steps: currentSteps,
                totalRouteDistance: totalRouteDistance
            )

            guidanceState = .active(
                ActiveGuidance(
                    currentInstruction: NavigationLogic.cleanHtmlInstruction(currentStep.instruction),
                    distanceToNextStepMeters: distanceToStepEnd,
                    currentStepIndex: currentStepIndex,
                    totalSteps: currentSteps.count,
                    routePolyline: routePolylinePoints,
                    remainingDistanceMeters: remainingDist,
                    estimatedTimeRemainingSeconds: remainingTime,
                    isRerouting: false
                )
            )
        }
    }

    private func advanceToNextStep(userLocation: CLLocationCoordinate2D) {
        currentStepIndex += 1

        if currentStepIndex >= currentSteps.count {
            guidanceState = .completed
            print("[NavigationManager] All steps completed")
            return
        }

        let nextStep = currentSteps[currentStepIndex]
        let distanceToEnd = NavigationLogic.calculateDistance(
            from: userLocation,
            to: nextStep.endLocation
        )

        let (remainingDist, remainingTime) = NavigationLogic.calculateRemainingStats(
            currentStepIndex: currentStepIndex,
            steps: currentSteps
        )

        navigationProgress = NavigationProgress.calculate(
            currentStepIndex: currentStepIndex,
            distanceToNextStep: distanceToEnd,
            steps: currentSteps,
            totalRouteDistance: totalRouteDistance
        )

        guidanceState = .active(
            ActiveGuidance(
                currentInstruction: NavigationLogic.cleanHtmlInstruction(nextStep.instruction),
                distanceToNextStepMeters: distanceToEnd,
                currentStepIndex: currentStepIndex,
                totalSteps: currentSteps.count,
                routePolyline: routePolylinePoints,
                remainingDistanceMeters: remainingDist,
                estimatedTimeRemainingSeconds: remainingTime,
                isRerouting: false
            )
        )

        print("[NavigationManager] Advanced to step \(currentStepIndex + 1)/\(currentSteps.count)")
    }

    private func handleOffRoute(
        userLocation: CLLocationCoordinate2D,
        activeGuidance: ActiveGuidance
    ) {
        let distanceOffRoute = NavigationLogic.calculateDistanceToPolyline(
            point: userLocation,
            polyline: routePolylinePoints
        )

        guidanceState = .offRoute(
            OffRouteGuidance(
                distanceOffRoute: distanceOffRoute,
                lastKnownGuidance: activeGuidance
            )
        )

        print("[NavigationManager] Off route: \(Int(distanceOffRoute))m")
    }

    func requestReroute(from: CLLocationCoordinate2D) async {
        guard let destination = destination else { return }
        guard !isRerouting else { return }

        isRerouting = true

        if case .active(let activeGuidance) = guidanceState {
            guidanceState = .active(
                ActiveGuidance(
                    currentInstruction: activeGuidance.currentInstruction,
                    distanceToNextStepMeters: activeGuidance.distanceToNextStepMeters,
                    currentStepIndex: activeGuidance.currentStepIndex,
                    totalSteps: activeGuidance.totalSteps,
                    routePolyline: activeGuidance.routePolyline,
                    remainingDistanceMeters: activeGuidance.remainingDistanceMeters,
                    estimatedTimeRemainingSeconds: activeGuidance.estimatedTimeRemainingSeconds,
                    isRerouting: true
                )
            )
        }

        print("[NavigationManager] Rerouting from current location")
    }

    func updateWithNewRoute(route: Route, userLocation: CLLocationCoordinate2D) {
        currentSteps = route.allSteps
        currentStepIndex = 0
        routePolylinePoints = route.decodedPolyline
        totalRouteDistance = route.totalDistance
        origin = userLocation
        isRerouting = false

        guard !currentSteps.isEmpty else {
            guidanceState = .error("No navigation steps in new route")
            return
        }

        let firstStep = currentSteps[0]
        let distanceToEnd = NavigationLogic.calculateDistance(
            from: userLocation,
            to: firstStep.endLocation
        )

        let (remainingDist, remainingTime) = NavigationLogic.calculateRemainingStats(
            currentStepIndex: currentStepIndex,
            steps: currentSteps
        )

        navigationProgress = NavigationProgress.calculate(
            currentStepIndex: currentStepIndex,
            distanceToNextStep: distanceToEnd,
            steps: currentSteps,
            totalRouteDistance: totalRouteDistance
        )

        guidanceState = .active(
            ActiveGuidance(
                currentInstruction: NavigationLogic.cleanHtmlInstruction(firstStep.instruction),
                distanceToNextStepMeters: distanceToEnd,
                currentStepIndex: currentStepIndex,
                totalSteps: currentSteps.count,
                routePolyline: routePolylinePoints,
                remainingDistanceMeters: remainingDist,
                estimatedTimeRemainingSeconds: remainingTime,
                isRerouting: false
            )
        )

        print("[NavigationManager] Reroute successful: \(currentSteps.count) new steps")
    }

    func stopGuidance() {
        currentSteps = []
        currentStepIndex = 0
        routePolylinePoints = []
        origin = nil
        destination = nil
        isRerouting = false
        totalRouteDistance = 0
        navigationProgress = nil
        guidanceState = .idle
        print("[NavigationManager] Guidance stopped")
    }

    var currentStep: RouteStep? {
        guard currentStepIndex < currentSteps.count else { return nil }
        return currentSteps[currentStepIndex]
    }

    var isNavigating: Bool {
        guidanceState.isActive
    }

    var shouldRequestReroute: Bool {
        guidanceState.isOffRoute && !isRerouting
    }
}
#endif
