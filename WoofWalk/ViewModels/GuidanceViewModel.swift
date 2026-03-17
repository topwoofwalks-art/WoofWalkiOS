import Foundation
import CoreLocation
import Combine

enum GuidanceState: Equatable {
    case idle

    case active(
        currentInstruction: String,
        distanceToNextStepMeters: Double,
        currentStepIndex: Int,
        totalSteps: Int,
        isOffRoute: Bool,
        isRerouting: Bool = false,
        routePolyline: [CLLocationCoordinate2D] = [],
        remainingDistanceMeters: Double = 0.0,
        estimatedTimeRemainingSeconds: Int = 0
    )

    case completed

    case error(String)

    static func == (lhs: GuidanceState, rhs: GuidanceState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.completed, .completed):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.active(let lhsInst, let lhsDist, let lhsIdx, let lhsTotal, let lhsOff, let lhsReroute, _, let lhsRemDist, let lhsETA),
              .active(let rhsInst, let rhsDist, let rhsIdx, let rhsTotal, let rhsOff, let rhsReroute, _, let rhsRemDist, let rhsETA)):
            return lhsInst == rhsInst &&
                   lhsDist == rhsDist &&
                   lhsIdx == rhsIdx &&
                   lhsTotal == rhsTotal &&
                   lhsOff == rhsOff &&
                   lhsReroute == rhsReroute &&
                   lhsRemDist == rhsRemDist &&
                   lhsETA == rhsETA
        default:
            return false
        }
    }
}

@MainActor
class GuidanceViewModel: ObservableObject {
    @Published private(set) var guidanceState: GuidanceState = .idle

    private var currentSteps: [RouteStep] = []
    private var currentStepIndex = 0
    private var routePolylinePoints: [CLLocationCoordinate2D] = []
    private var origin: CLLocationCoordinate2D?
    private var destination: CLLocationCoordinate2D?
    private var isRerouting = false

    private let offRouteThresholdMeters = 30.0
    private let stepCompletionThresholdMeters = 15.0

    private let routingViewModel: RoutingViewModel

    init(routingViewModel: RoutingViewModel = RoutingViewModel()) {
        self.routingViewModel = routingViewModel
    }

    func startGuidance(route: Route, userLocation: CLLocationCoordinate2D) {
        currentSteps = route.legs.flatMap { $0.steps }
        currentStepIndex = 0
        routePolylinePoints = decodePolyline(encoded: route.overviewPolyline)

        origin = userLocation
        destination = routePolylinePoints.last

        guard !currentSteps.isEmpty else {
            guidanceState = .error("No navigation steps available")
            return
        }

        let firstStep = currentSteps[0]
        let distanceToEnd = calculateDistance(loc1: userLocation, loc2: firstStep.endLocation)

        let (remainingDist, remainingTime) = calculateRemainingStats()

        print("[GuidanceVM] Starting guidance: user=\(userLocation.latitude),\(userLocation.longitude), stepEnd=\(firstStep.endLocation.latitude),\(firstStep.endLocation.longitude), distance=\(distanceToEnd)m")

        guidanceState = .active(
            currentInstruction: cleanHtmlInstruction(firstStep.htmlInstructions),
            distanceToNextStepMeters: distanceToEnd,
            currentStepIndex: 0,
            totalSteps: currentSteps.count,
            isOffRoute: false,
            isRerouting: false,
            routePolyline: routePolylinePoints,
            remainingDistanceMeters: remainingDist,
            estimatedTimeRemainingSeconds: remainingTime
        )

        print("[GuidanceVM] Guidance started: \(currentSteps.count) steps")
    }

    func updateUserLocation(_ userLocation: CLLocationCoordinate2D) {
        guard case .active = guidanceState else { return }
        guard !isRerouting else { return }

        let distanceToPolyline = calculateDistanceToPolyline(point: userLocation, polyline: routePolylinePoints)
        let isOffRoute = distanceToPolyline > offRouteThresholdMeters

        if isOffRoute && !isRerouting {
            handleOffRoute(userLocation: userLocation)
            return
        }

        if currentStepIndex >= currentSteps.count {
            guidanceState = .completed
            print("[GuidanceVM] Guidance completed")
            return
        }

        let currentStep = currentSteps[currentStepIndex]
        let distanceToStepEnd = calculateDistance(loc1: userLocation, loc2: currentStep.endLocation)

        print("[GuidanceVM] Tracking: user=\(userLocation.latitude),\(userLocation.longitude), stepEnd=\(currentStep.endLocation.latitude),\(currentStep.endLocation.longitude), distance=\(distanceToStepEnd)m")

        if distanceToStepEnd <= stepCompletionThresholdMeters {
            advanceToNextStep(userLocation: userLocation)
        } else {
            let (remainingDist, remainingTime) = calculateRemainingStats()

            guidanceState = .active(
                currentInstruction: cleanHtmlInstruction(currentStep.htmlInstructions),
                distanceToNextStepMeters: distanceToStepEnd,
                currentStepIndex: currentStepIndex,
                totalSteps: currentSteps.count,
                isOffRoute: false,
                isRerouting: false,
                routePolyline: routePolylinePoints,
                remainingDistanceMeters: remainingDist,
                estimatedTimeRemainingSeconds: remainingTime
            )
        }
    }

    func requestReroute(from userLocation: CLLocationCoordinate2D) {
        guard let dest = destination else { return }
        handleOffRoute(userLocation: userLocation)
    }

    func pauseGuidance() {
        print("[GuidanceVM] Guidance paused")
    }

    func resumeGuidance() {
        print("[GuidanceVM] Guidance resumed")
    }

    func stopGuidance() {
        currentSteps = []
        currentStepIndex = 0
        routePolylinePoints = []
        origin = nil
        destination = nil
        isRerouting = false
        guidanceState = .idle
        print("[GuidanceVM] Guidance stopped")
    }

    private func advanceToNextStep(userLocation: CLLocationCoordinate2D) {
        currentStepIndex += 1

        if currentStepIndex >= currentSteps.count {
            guidanceState = .completed
            print("[GuidanceVM] All steps completed")
            return
        }

        let nextStep = currentSteps[currentStepIndex]
        let distanceToEnd = calculateDistance(loc1: userLocation, loc2: nextStep.endLocation)

        let (remainingDist, remainingTime) = calculateRemainingStats()

        guidanceState = .active(
            currentInstruction: cleanHtmlInstruction(nextStep.htmlInstructions),
            distanceToNextStepMeters: distanceToEnd,
            currentStepIndex: currentStepIndex,
            totalSteps: currentSteps.count,
            isOffRoute: false,
            isRerouting: false,
            routePolyline: routePolylinePoints,
            remainingDistanceMeters: remainingDist,
            estimatedTimeRemainingSeconds: remainingTime
        )

        print("[GuidanceVM] Advanced to step \(currentStepIndex + 1)/\(currentSteps.count)")
    }

    private func handleOffRoute(userLocation: CLLocationCoordinate2D) {
        if case .active(let inst, let dist, let idx, let total, _, let reroute, let poly, let remDist, let eta) = guidanceState {
            guidanceState = .active(
                currentInstruction: inst,
                distanceToNextStepMeters: dist,
                currentStepIndex: idx,
                totalSteps: total,
                isOffRoute: true,
                isRerouting: reroute,
                routePolyline: poly,
                remainingDistanceMeters: remDist,
                estimatedTimeRemainingSeconds: eta
            )
        }

        guard let dest = destination else { return }
        Task {
            await rerouteFromCurrentLocation(from: userLocation, to: dest)
        }
    }

    private func rerouteFromCurrentLocation(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async {
        guard !isRerouting else { return }

        isRerouting = true
        print("[GuidanceVM] Rerouting from current location")

        if case .active(let inst, let dist, let idx, let total, let offRoute, _, let poly, let remDist, let eta) = guidanceState {
            guidanceState = .active(
                currentInstruction: inst,
                distanceToNextStepMeters: dist,
                currentStepIndex: idx,
                totalSteps: total,
                isOffRoute: offRoute,
                isRerouting: true,
                routePolyline: poly,
                remainingDistanceMeters: remDist,
                estimatedTimeRemainingSeconds: eta
            )
        }

        routingViewModel.onMapTap(origin: from, destination: to, destinationName: "Rerouting...")

        try? await Task.sleep(nanoseconds: 2_000_000_000)

        if case .previewReady(let preview) = routingViewModel.routingState,
           let newRoute = preview.route {

            let newPolyline = decodePolyline(encoded: newRoute.overviewPolyline)
            routePolylinePoints = newPolyline
            currentSteps = newRoute.legs.flatMap { $0.steps }
            currentStepIndex = 0
            origin = from

            if !currentSteps.isEmpty {
                let firstStep = currentSteps[0]
                let distanceToEnd = calculateDistance(loc1: from, loc2: firstStep.endLocation)

                let (remainingDist, remainingTime) = calculateRemainingStats()

                guidanceState = .active(
                    currentInstruction: cleanHtmlInstruction(firstStep.htmlInstructions),
                    distanceToNextStepMeters: distanceToEnd,
                    currentStepIndex: 0,
                    totalSteps: currentSteps.count,
                    isOffRoute: false,
                    isRerouting: false,
                    routePolyline: routePolylinePoints,
                    remainingDistanceMeters: remainingDist,
                    estimatedTimeRemainingSeconds: remainingTime
                )

                print("[GuidanceVM] Reroute successful: \(currentSteps.count) new steps")
            }
        } else {
            handleRerouteFailure()
        }

        isRerouting = false
    }

    private func handleRerouteFailure() {
        if case .active(let inst, let dist, let idx, let total, _, _, let poly, let remDist, let eta) = guidanceState {
            guidanceState = .active(
                currentInstruction: inst,
                distanceToNextStepMeters: dist,
                currentStepIndex: idx,
                totalSteps: total,
                isOffRoute: true,
                isRerouting: false,
                routePolyline: poly,
                remainingDistanceMeters: remDist,
                estimatedTimeRemainingSeconds: eta
            )
        }
    }

    private func calculateRemainingStats() -> (Double, Int) {
        var remainingDistance = 0.0
        var remainingTime = 0

        for i in currentStepIndex..<currentSteps.count {
            remainingDistance += Double(currentSteps[i].distance.value)
            remainingTime += currentSteps[i].duration.value
        }

        return (remainingDistance, remainingTime)
    }

    private func cleanHtmlInstruction(_ html: String) -> String {
        return html
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "<div style=\"font-size:0.9em\">", with: " ")
            .replacingOccurrences(of: "</div>", with: "")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func calculateDistanceToPolyline(point: CLLocationCoordinate2D, polyline: [CLLocationCoordinate2D]) -> Double {
        if polyline.isEmpty { return Double.greatestFiniteMagnitude }
        if polyline.count == 1 { return calculateDistance(loc1: point, loc2: polyline[0]) }

        var minDistance = Double.greatestFiniteMagnitude

        for i in 0..<(polyline.count - 1) {
            let segmentStart = polyline[i]
            let segmentEnd = polyline[i + 1]
            let distance = distanceToLineSegment(point: point, lineStart: segmentStart, lineEnd: segmentEnd)

            if distance < minDistance {
                minDistance = distance
            }
        }

        return minDistance
    }

    private func distanceToLineSegment(point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let x0 = point.latitude
        let y0 = point.longitude
        let x1 = lineStart.latitude
        let y1 = lineStart.longitude
        let x2 = lineEnd.latitude
        let y2 = lineEnd.longitude

        let dx = x2 - x1
        let dy = y2 - y1

        if dx == 0.0 && dy == 0.0 {
            return calculateDistance(loc1: point, loc2: lineStart)
        }

        let t = ((x0 - x1) * dx + (y0 - y1) * dy) / (dx * dx + dy * dy)

        let closestPoint: CLLocationCoordinate2D
        if t < 0 {
            closestPoint = lineStart
        } else if t > 1 {
            closestPoint = lineEnd
        } else {
            closestPoint = CLLocationCoordinate2D(latitude: x1 + t * dx, longitude: y1 + t * dy)
        }

        return calculateDistance(loc1: point, loc2: closestPoint)
    }

    private func calculateDistance(loc1: CLLocationCoordinate2D, loc2: CLLocationCoordinate2D) -> Double {
        let earthRadiusMeters = 6371000.0
        let dLat = (loc2.latitude - loc1.latitude).toRadians()
        let dLng = (loc2.longitude - loc1.longitude).toRadians()
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(loc1.latitude.toRadians()) * cos(loc2.latitude.toRadians()) *
                sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }

    private func decodePolyline(encoded: String) -> [CLLocationCoordinate2D] {
        var poly = [CLLocationCoordinate2D]()
        var index = encoded.startIndex
        var lat = 0
        var lng = 0

        while index < encoded.endIndex {
            var b: Int
            var shift = 0
            var result = 0
            repeat {
                b = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result = result | ((b & 0x1f) << shift)
                shift += 5
            } while b >= 0x20
            let dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1)
            lat += dlat

            shift = 0
            result = 0
            repeat {
                b = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result = result | ((b & 0x1f) << shift)
                shift += 5
            } while b >= 0x20
            let dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1)
            lng += dlng

            poly.append(CLLocationCoordinate2D(latitude: Double(lat) / 1E5, longitude: Double(lng) / 1E5))
        }

        return poly
    }
}

// toRadians() is defined in RoutingViewModel.swift
