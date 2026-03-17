#if false
// DISABLED: Duplicate Direction types - Distance/Duration conflict with RoutingViewModel.swift
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
    let distance: Distance
    let duration: Duration
    let startLocation: Location
    let endLocation: Location
    let steps: [DirectionsStep]

    init(
        distance: Distance = Distance(),
        duration: Duration = Duration(),
        startLocation: Location = Location(),
        endLocation: Location = Location(),
        steps: [DirectionsStep] = []
    ) {
        self.distance = distance
        self.duration = duration
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.steps = steps
    }
}

struct Distance: Codable {
    let value: Int
    let text: String

    init(value: Int = 0, text: String = "") {
        self.value = value
        self.text = text
    }
}

struct Duration: Codable {
    let value: Int
    let text: String

    init(value: Int = 0, text: String = "") {
        self.value = value
        self.text = text
    }
}

struct Location: Codable {
    let lat: Double
    let lng: Double

    init(lat: Double = 0.0, lng: Double = 0.0) {
        self.lat = lat
        self.lng = lng
    }
}

struct DirectionsStep: Codable {
    let htmlInstructions: String
    let distance: Distance
    let duration: Duration
    let startLocation: Location
    let endLocation: Location
    let polyline: OverviewPolyline
    let travelMode: String
    let maneuver: String?

    init(
        htmlInstructions: String = "",
        distance: Distance = Distance(),
        duration: Duration = Duration(),
        startLocation: Location = Location(),
        endLocation: Location = Location(),
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
    let northeast: Location
    let southwest: Location

    init(
        northeast: Location = Location(),
        southwest: Location = Location()
    ) {
        self.northeast = northeast
        self.southwest = southwest
    }
}
#endif
