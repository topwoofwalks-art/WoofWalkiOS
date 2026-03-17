import Foundation

struct DirectionsResponse: Codable {
    let routes: [DirectionsRoute]
    let status: String

    init(routes: [DirectionsRoute] = [], status: String = "") {
        self.routes = routes
        self.status = status
    }
}

struct DirectionsRoute: Codable {
    let summary: String
    let overviewPolyline: OverviewPolyline
    let legs: [DirectionsLeg]
    let warnings: [String]
    let bounds: Bounds?

    init(
        summary: String = "",
        overviewPolyline: OverviewPolyline = OverviewPolyline(),
        legs: [DirectionsLeg] = [],
        warnings: [String] = [],
        bounds: Bounds? = nil
    ) {
        self.summary = summary
        self.overviewPolyline = overviewPolyline
        self.legs = legs
        self.warnings = warnings
        self.bounds = bounds
    }
}

struct OverviewPolyline: Codable {
    let points: String

    init(points: String = "") {
        self.points = points
    }
}

struct DirectionsLeg: Codable {
    let distance: DirectionsDistance
    let duration: DirectionsDuration
    let startLocation: DirectionsLocation
    let endLocation: DirectionsLocation
    let steps: [DirectionsStep]

    init(
        distance: DirectionsDistance = DirectionsDistance(),
        duration: DirectionsDuration = DirectionsDuration(),
        startLocation: DirectionsLocation = DirectionsLocation(),
        endLocation: DirectionsLocation = DirectionsLocation(),
        steps: [DirectionsStep] = []
    ) {
        self.distance = distance
        self.duration = duration
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.steps = steps
    }
}

struct DirectionsDistance: Codable {
    let value: Int
    let text: String

    init(value: Int = 0, text: String = "") {
        self.value = value
        self.text = text
    }
}

struct DirectionsDuration: Codable {
    let value: Int
    let text: String

    init(value: Int = 0, text: String = "") {
        self.value = value
        self.text = text
    }
}

struct DirectionsLocation: Codable {
    let lat: Double
    let lng: Double

    init(lat: Double = 0.0, lng: Double = 0.0) {
        self.lat = lat
        self.lng = lng
    }
}

struct DirectionsStep: Codable {
    let htmlInstructions: String
    let distance: DirectionsDistance
    let duration: DirectionsDuration
    let startLocation: DirectionsLocation
    let endLocation: DirectionsLocation
    let polyline: OverviewPolyline
    let travelMode: String
    let maneuver: String?

    init(
        htmlInstructions: String = "",
        distance: DirectionsDistance = DirectionsDistance(),
        duration: DirectionsDuration = DirectionsDuration(),
        startLocation: DirectionsLocation = DirectionsLocation(),
        endLocation: DirectionsLocation = DirectionsLocation(),
        polyline: OverviewPolyline = OverviewPolyline(),
        travelMode: String = "WALKING",
        maneuver: String? = nil
    ) {
        self.htmlInstructions = htmlInstructions
        self.distance = distance
        self.duration = duration
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.polyline = polyline
        self.travelMode = travelMode
        self.maneuver = maneuver
    }
}

struct Bounds: Codable {
    let northeast: DirectionsLocation
    let southwest: DirectionsLocation

    init(
        northeast: DirectionsLocation = DirectionsLocation(),
        southwest: DirectionsLocation = DirectionsLocation()
    ) {
        self.northeast = northeast
        self.southwest = southwest
    }
}
