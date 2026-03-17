#if false
// DISABLED: Duplicate OSRM types - real versions inline in RoutingViewModel.swift
import Foundation

struct OsrmRouteResponse: Codable {
    let code: String
    let routes: [OsrmRoute]?
    let waypoints: [OsrmWaypoint]?
    let message: String?
}

struct OsrmRoute: Codable {
    let geometry: String
    let legs: [OsrmLeg]
    let distance: Double
    let duration: Double
}

struct OsrmLeg: Codable {
    let steps: [OsrmStep]
    let distance: Double
    let duration: Double
}

struct OsrmStep: Codable {
    let geometry: String
    let distance: Double
    let duration: Double
    let name: String
    let mode: String
}

struct OsrmWaypoint: Codable {
    let name: String
    let location: [Double]
}

struct OsrmNearestResponse: Codable {
    let code: String
    let waypoints: [OsrmNearestWaypoint]?
    let message: String?
}

struct OsrmNearestWaypoint: Codable {
    let location: [Double]
    let name: String
    let distance: Double?
}
#endif
