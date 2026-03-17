import Foundation

// OsrmRouteResponse, OsrmRoute, OsrmLeg, OsrmStep, OsrmWaypoint
// are defined in RoutingViewModel.swift. Only Nearest types live here.

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
