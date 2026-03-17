import Foundation
import CoreLocation
import Combine

// MARK: - Route Types
enum RouteType {
    case randomWalk
    case pointToPoint
}

enum PathPreference {
    case footpathPriority
    case roadPriority
}

enum RouteComplexity {
    case fullComplex
    case simplified
    case basicCircular
    case outAndBack
}

// MARK: - OSRM API Models
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

// MARK: - Route Models
struct RoutePreview {
    let destination: CLLocationCoordinate2D
    let destinationName: String
    let straightLineDistance: Double
    let eta: String?
    let route: Route?
    let isLoading: Bool
    let error: String?
    let isRecalculating: Bool
    let recalculatingMessage: String?
    let routeType: RouteType
    let pathPreference: PathPreference
    let poiList: [String]

    init(destination: CLLocationCoordinate2D,
         destinationName: String,
         straightLineDistance: Double,
         eta: String? = nil,
         route: Route? = nil,
         isLoading: Bool = false,
         error: String? = nil,
         isRecalculating: Bool = false,
         recalculatingMessage: String? = nil,
         routeType: RouteType = .pointToPoint,
         pathPreference: PathPreference = .footpathPriority,
         poiList: [String] = []) {
        self.destination = destination
        self.destinationName = destinationName
        self.straightLineDistance = straightLineDistance
        self.eta = eta
        self.route = route
        self.isLoading = isLoading
        self.error = error
        self.isRecalculating = isRecalculating
        self.recalculatingMessage = recalculatingMessage
        self.routeType = routeType
        self.pathPreference = pathPreference
        self.poiList = poiList
    }
}

struct Route {
    let summary: String
    let overviewPolyline: String
    let legs: [RouteLeg]
    let warnings: [String]
}

struct RouteLeg {
    let distance: Distance
    let duration: Duration
    let startLocation: CLLocationCoordinate2D
    let endLocation: CLLocationCoordinate2D
    let steps: [RouteStep]
}

struct RouteStep {
    let htmlInstructions: String
    let distance: Distance
    let duration: Duration
    let startLocation: CLLocationCoordinate2D
    let endLocation: CLLocationCoordinate2D
    let polyline: String
    let travelMode: String
    let maneuver: String?
}

struct Distance {
    let value: Int
    let text: String
}

struct Duration {
    let value: Int
    let text: String
}

// MARK: - Routing State
enum RoutingState {
    case idle
    case previewReady(RoutePreview)
    case error(String)
}

// POI models: uses Poi from Models/Poi.swift and PoiType from Models/POI/POI.swift

// MARK: - Routing ViewModel
@MainActor
class RoutingViewModel: ObservableObject {
    @Published var routingState: RoutingState = .idle

    private let osrmBaseURL = "https://router.project-osrm.org"
    private var debounceTask: Task<Void, Never>?
    private let routeCache = RouteCache()

    // MARK: - Public API
    func onMapTap(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, destinationName: String = "Selected Location") {
        print("[RoutingVM] onMapTap: origin=\(origin), destination=\(destination)")

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            do {
                let straightLineDistance = calculateHaversineDistance(from: origin, to: destination)
                print("[RoutingVM] Calculated straight-line distance: \(Int(straightLineDistance))m")

                let initialPreview = RoutePreview(
                    destination: destination,
                    destinationName: destinationName,
                    straightLineDistance: straightLineDistance,
                    isLoading: true
                )

                routingState = .previewReady(initialPreview)

                await fetchDirections(origin: origin, destination: destination, initialPreview: initialPreview)
            } catch {
                print("[RoutingVM] Error creating route preview: \(error)")
                routingState = .error(error.localizedDescription)
            }
        }
    }

    func clearRoutePreview() {
        routingState = .idle
    }

    func generateCircularRoute(userLocation: CLLocationCoordinate2D, viaPoint: CLLocationCoordinate2D, desiredDistance: Double = 5000.0) {
        print("[RoutingVM] Generating circular route: user=\(userLocation), via=\(viaPoint), distance=\(Int(desiredDistance))m")

        debounceTask?.cancel()
        debounceTask = Task {
            do {
                let straightLineDistance = calculateHaversineDistance(from: userLocation, to: viaPoint)

                let initialPreview = RoutePreview(
                    destination: userLocation,
                    destinationName: "Random Walk (\(Int(desiredDistance / 1000))km)",
                    straightLineDistance: straightLineDistance,
                    isLoading: true,
                    routeType: .randomWalk,
                    pathPreference: .footpathPriority
                )

                routingState = .previewReady(initialPreview)

                let waypoints = [viaPoint]
                print("[RoutingVM] Generated \(waypoints.count) waypoints for circular route")

                await fetchCircularRoute(
                    origin: userLocation,
                    waypoints: waypoints,
                    initialPreview: initialPreview,
                    preferPathsOverRoads: true,
                    viaPoint: viaPoint,
                    desiredDistance: desiredDistance,
                    complexity: .fullComplex
                )
            } catch {
                print("[RoutingVM] Error generating circular route: \(error)")
                routingState = .error(error.localizedDescription)
            }
        }
    }

    func generateCircularRouteWithPois(
        userLocation: CLLocationCoordinate2D,
        viaPoint: CLLocationCoordinate2D,
        selectedPois: [Poi],
        availablePois: [Poi] = [],
        desiredDistance: Double = 5000.0,
        preferPathsOverRoads: Bool = true
    ) {
        print("[RoutingVM] Generating circular route with \(selectedPois.count) POIs: user=\(userLocation), via=\(viaPoint), distance=\(Int(desiredDistance))m")

        debounceTask?.cancel()
        debounceTask = Task {
            do {
                let straightLineDistance = calculateHaversineDistance(from: userLocation, to: viaPoint)

                let initialPreview = RoutePreview(
                    destination: userLocation,
                    destinationName: selectedPois.isEmpty ? "Generating optimal random walk..." : "Random Walk (\(Int(desiredDistance / 1000))km) via \(selectedPois.count) POIs",
                    straightLineDistance: straightLineDistance,
                    isLoading: true,
                    routeType: .randomWalk,
                    pathPreference: preferPathsOverRoads ? .footpathPriority : .roadPriority,
                    poiList: selectedPois.map { $0.title }
                )

                routingState = .previewReady(initialPreview)

                print("[RoutingVM] Waypoint selection: selectedPois=\(selectedPois.count), availablePois=\(availablePois.count)")

                let pentagonWaypoints = generateCircularWaypointPattern(userLocation: userLocation, viaPoint: viaPoint, desiredDistance: desiredDistance)
                print("[RoutingVM] Generated \(pentagonWaypoints.count) pentagon waypoints")

                var poisToInsert = [CLLocationCoordinate2D]()
                poisToInsert.append(viaPoint)

                var routePoiNames = [String]()

                if !selectedPois.isEmpty {
                    print("[RoutingVM] Adding \(selectedPois.count) selected POIs")
                    poisToInsert.append(contentsOf: selectedPois.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) })
                    routePoiNames.append(contentsOf: selectedPois.map { $0.title })
                }

                var waypoints = insertPoisIntoPentagon(origin: userLocation, pentagonWaypoints: pentagonWaypoints, poisToInsert: poisToInsert)

                smoothUturns(points: &waypoints)

                print("[RoutingVM] Final route has \(waypoints.count) waypoints (\(pentagonWaypoints.count) pentagon + POIs)")

                let updatedPreview: RoutePreview
                if !routePoiNames.isEmpty {
                    let poiNamesStr = routePoiNames.prefix(3).joined(separator: ", ")
                    let suffix = routePoiNames.count > 3 ? "..." : ""
                    updatedPreview = RoutePreview(
                        destination: initialPreview.destination,
                        destinationName: "Walk via \(poiNamesStr)\(suffix)",
                        straightLineDistance: initialPreview.straightLineDistance,
                        isLoading: initialPreview.isLoading,
                        routeType: initialPreview.routeType,
                        pathPreference: initialPreview.pathPreference,
                        poiList: routePoiNames
                    )
                } else {
                    updatedPreview = initialPreview
                }

                await fetchCircularRoute(
                    origin: userLocation,
                    waypoints: waypoints,
                    initialPreview: updatedPreview,
                    preferPathsOverRoads: preferPathsOverRoads,
                    viaPoint: viaPoint,
                    desiredDistance: desiredDistance,
                    complexity: .fullComplex
                )
            } catch {
                print("[RoutingVM] Error generating circular route with POIs: \(error)")
                routingState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Private Helpers
    private func fetchDirections(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, initialPreview: RoutePreview) async {
        do {
            if let cachedRoute = routeCache.get(origin: origin, destination: destination) {
                print("[RoutingVM] Using cached route")
                updatePreviewWithRoute(preview: initialPreview, route: cachedRoute)
                return
            }

            if let route = await tryFetchRoute(origin: origin, destination: destination) {
                print("[RoutingVM] Route found: \(route.legs.count) legs")
                routeCache.put(origin: origin, destination: destination, route: route)
                updatePreviewWithRoute(preview: initialPreview, route: route)
                return
            }

            print("[RoutingVM] No route found, trying nearby locations...")
            let offsets: [(Double, Double)] = [
                (0.0001, 0.0),
                (-0.0001, 0.0),
                (0.0, 0.0001),
                (0.0, -0.0001),
                (0.0001, 0.0001)
            ]

            for (latOffset, lngOffset) in offsets {
                let adjustedDest = CLLocationCoordinate2D(
                    latitude: destination.latitude + latOffset,
                    longitude: destination.longitude + lngOffset
                )

                if let adjustedRoute = await tryFetchRoute(origin: origin, destination: adjustedDest) {
                    print("[RoutingVM] Found route with adjusted destination")
                    routeCache.put(origin: origin, destination: destination, route: adjustedRoute)
                    updatePreviewWithRoute(preview: initialPreview, route: adjustedRoute)
                    return
                }
            }

            print("[RoutingVM] No route found after trying multiple locations")
            routingState = .previewReady(RoutePreview(
                destination: initialPreview.destination,
                destinationName: initialPreview.destinationName,
                straightLineDistance: initialPreview.straightLineDistance,
                isLoading: false
            ))

        } catch {
            print("[RoutingVM] Error fetching directions: \(error)")
            routingState = .previewReady(RoutePreview(
                destination: initialPreview.destination,
                destinationName: initialPreview.destinationName,
                straightLineDistance: initialPreview.straightLineDistance,
                isLoading: false,
                error: "Could not fetch route: \(error.localizedDescription)"
            ))
        }
    }

    private func tryFetchRoute(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) async -> Route? {
        do {
            let coordinates = "\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)"

            print("[RoutingVM] Trying OSRM route: \(coordinates)")

            var urlComponents = URLComponents(string: "\(osrmBaseURL)/route/v1/foot/\(coordinates)")!
            urlComponents.queryItems = [
                URLQueryItem(name: "overview", value: "full"),
                URLQueryItem(name: "geometries", value: "polyline"),
                URLQueryItem(name: "steps", value: "true")
            ]

            guard let url = urlComponents.url else { return nil }

            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OsrmRouteResponse.self, from: data)

            if response.code != "Ok" {
                print("[RoutingVM] OSRM returned: \(response.code)")
                return nil
            }

            guard let osrmRoute = response.routes?.first else {
                print("[RoutingVM] No routes in response")
                return nil
            }

            return convertOsrmToRoute(osrmRoute: osrmRoute)
        } catch {
            print("[RoutingVM] Failed to fetch route: \(error)")
            return nil
        }
    }

    private func fetchCircularRoute(
        origin: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        initialPreview: RoutePreview,
        preferPathsOverRoads: Bool = true,
        viaPoint: CLLocationCoordinate2D? = nil,
        desiredDistance: Double = 5000.0,
        complexity: RouteComplexity = .fullComplex
    ) async {
        do {
            print("[RoutingVM] === CIRCULAR ROUTE START (Complexity: \(complexity)) ===")
            print("[RoutingVM] Origin: \(origin.latitude),\(origin.longitude)")
            print("[RoutingVM] Waypoints count: \(waypoints.count)")
            for (i, wp) in waypoints.enumerated() {
                print("[RoutingVM]   Waypoint \(i): \(wp.latitude),\(wp.longitude)")
            }

            var segments = [(CLLocationCoordinate2D, CLLocationCoordinate2D)]()
            segments.append((origin, waypoints[0]))

            for i in 0..<(waypoints.count - 1) {
                segments.append((waypoints[i], waypoints[i + 1]))
            }

            segments.append((waypoints.last!, origin))

            print("[RoutingVM] Created \(segments.count) segments to fetch")

            let firstSegmentBearing = !segments.isEmpty ? Int(calculateBearing(from: segments[0].0, to: segments[0].1)) : nil

            var allLegs = [RouteLeg]()
            var allPolylinePoints = [CLLocationCoordinate2D]()
            var totalDistance = 0
            var totalDuration = 0

            for (index, segment) in segments.enumerated() {
                print("[RoutingVM] Fetching segment \(index + 1)/\(segments.count)")

                let isLastLeg = (index == segments.count - 1)

                let osrmRoute = try await fetchSegmentAvoidingOverlap(
                    start: segment.0,
                    end: segment.1,
                    used: allPolylinePoints,
                    segmentIndex: index + 1,
                    totalSegments: segments.count,
                    isLastLeg: isLastLeg,
                    firstSegmentBearing: firstSegmentBearing
                )

                let segmentRoute = convertOsrmToRoute(osrmRoute: osrmRoute)
                allLegs.append(contentsOf: segmentRoute.legs)

                let segmentPoints = decodePolyline(encoded: osrmRoute.geometry)
                if index == 0 {
                    allPolylinePoints.append(contentsOf: segmentPoints)
                } else {
                    allPolylinePoints.append(contentsOf: segmentPoints.dropFirst())
                }

                totalDistance += Int(osrmRoute.distance)
                totalDuration += Int(osrmRoute.duration)

                print("[RoutingVM] Segment \(index + 1) complete: \(Int(osrmRoute.distance))m, \(Int(osrmRoute.duration))s")
            }

            let combinedPolyline = encodePolyline(points: allPolylinePoints)

            let combinedRoute = Route(
                summary: "Random Walking Route",
                overviewPolyline: combinedPolyline,
                legs: allLegs,
                warnings: []
            )

            print("[RoutingVM] Random walk complete: \(allLegs.count) legs, \(totalDistance)m total, \(totalDuration)s")

            let overlapPercentage = calculateRouteOverlap(route: combinedRoute)
            print("[RoutingVM] Route overlap: \(String(format: "%.1f", overlapPercentage))%")

            updatePreviewWithRoute(preview: initialPreview, route: combinedRoute)

        } catch {
            print("[RoutingVM] Error fetching circular route at complexity level: \(complexity)")

            if let viaPoint = viaPoint, complexity != .outAndBack {
                let nextComplexity: RouteComplexity? = {
                    switch complexity {
                    case .fullComplex: return .simplified
                    case .simplified: return .basicCircular
                    case .basicCircular: return .outAndBack
                    case .outAndBack: return nil
                    }
                }()

                if let nextComplexity = nextComplexity {
                    print("[RoutingVM] Attempting fallback to \(nextComplexity)")

                    let fallbackMessage: String = {
                        switch nextComplexity {
                        case .simplified: return "Calculating alternative route (simplified)..."
                        case .basicCircular: return "Calculating alternative route (basic)..."
                        case .outAndBack: return "Calculating alternative route (direct)..."
                        default: return "Recalculating route..."
                        }
                    }()

                    routingState = .previewReady(RoutePreview(
                        destination: initialPreview.destination,
                        destinationName: initialPreview.destinationName,
                        straightLineDistance: initialPreview.straightLineDistance,
                        isRecalculating: true,
                        recalculatingMessage: fallbackMessage,
                        routeType: initialPreview.routeType,
                        pathPreference: initialPreview.pathPreference,
                        poiList: initialPreview.poiList
                    ))

                    try? await Task.sleep(nanoseconds: 500_000_000)

                    let fallbackWaypoints: [CLLocationCoordinate2D] = {
                        switch nextComplexity {
                        case .simplified: return generateSimplifiedWaypoints(userLocation: origin, viaPoint: viaPoint, desiredDistance: desiredDistance)
                        case .basicCircular: return [viaPoint]
                        case .outAndBack: return generateOutAndBackWaypoints(userLocation: origin, viaPoint: viaPoint)
                        default: return waypoints
                        }
                    }()

                    await fetchCircularRoute(
                        origin: origin,
                        waypoints: fallbackWaypoints,
                        initialPreview: RoutePreview(
                            destination: initialPreview.destination,
                            destinationName: initialPreview.destinationName,
                            straightLineDistance: initialPreview.straightLineDistance,
                            routeType: initialPreview.routeType,
                            pathPreference: initialPreview.pathPreference,
                            poiList: initialPreview.poiList
                        ),
                        preferPathsOverRoads: preferPathsOverRoads,
                        viaPoint: viaPoint,
                        desiredDistance: desiredDistance,
                        complexity: nextComplexity
                    )
                    return
                }
            }

            routingState = .previewReady(RoutePreview(
                destination: initialPreview.destination,
                destinationName: initialPreview.destinationName,
                straightLineDistance: initialPreview.straightLineDistance,
                isLoading: false,
                error: "Could not generate circular route: \(error.localizedDescription)"
            ))
        }
    }

    private func fetchSegmentAvoidingOverlap(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        used: [CLLocationCoordinate2D],
        segmentIndex: Int,
        totalSegments: Int,
        isLastLeg: Bool = false,
        firstSegmentBearing: Int? = nil
    ) async throws -> OsrmRoute {
        var currentStart = start
        var currentEnd = end

        for attempt in 0...2 {
            let coordinates = "\(currentStart.longitude),\(currentStart.latitude);\(currentEnd.longitude),\(currentEnd.latitude)"

            var startBearing = Int(calculateBearing(from: currentStart, to: currentEnd))
            var endBearing = (startBearing + 180) % 360

            if isLastLeg, let firstSegmentBearing = firstSegmentBearing {
                let returnBearing = Int(calculateBearing(from: currentStart, to: currentEnd))
                let bearingDiff = abs((firstSegmentBearing - returnBearing + 180) % 360 - 180)

                if bearingDiff < 30 {
                    startBearing = (startBearing + 20) % 360
                    print("[RoutingVM] Last-leg guard: adjusted bearing to avoid outbound street (diff=\(bearingDiff)°)")
                }
            }

            let bearingsParam = attempt < 2 ? "\(startBearing),180;\(endBearing),180" : nil
            let radiusesParam = "100;100"

            var urlComponents = URLComponents(string: "\(osrmBaseURL)/route/v1/foot/\(coordinates)")!
            var queryItems = [
                URLQueryItem(name: "overview", value: "full"),
                URLQueryItem(name: "geometries", value: "polyline"),
                URLQueryItem(name: "steps", value: "true"),
                URLQueryItem(name: "alternatives", value: "true")
            ]

            if let bearingsParam = bearingsParam {
                queryItems.append(URLQueryItem(name: "bearings", value: bearingsParam))
            }
            queryItems.append(URLQueryItem(name: "radiuses", value: radiusesParam))

            urlComponents.queryItems = queryItems

            guard let url = urlComponents.url else {
                throw NSError(domain: "RoutingViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }

            print("[RoutingVM] OSRM Request: \(url)")

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 400 {
                    if attempt < 2 {
                        print("[RoutingVM] HTTP 400 error, retrying without bearings (attempt \(attempt + 1)/3)")
                        continue
                    }
                    throw NSError(domain: "RoutingViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "HTTP 400 error"])
                }

                let osrmResponse = try JSONDecoder().decode(OsrmRouteResponse.self, from: data)

                if osrmResponse.code != "Ok" {
                    if attempt < 2 {
                        print("[RoutingVM] OSRM returned \(osrmResponse.code), retrying (attempt \(attempt + 1)/3)")
                        continue
                    }
                    throw NSError(domain: "RoutingViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "OSRM API error: \(osrmResponse.code) - \(osrmResponse.message ?? "")"])
                }

                let routes = osrmResponse.routes ?? []
                if routes.isEmpty {
                    if attempt < 2 {
                        print("[RoutingVM] No routes found, retrying (attempt \(attempt + 1)/3)")
                        continue
                    }
                    throw NSError(domain: "RoutingViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No route found"])
                }

                let bestRoute = routes.min { r1, r2 in
                    let overlap1 = overlapScore(candidate: r1.geometry, used: used)
                    let overlap2 = overlapScore(candidate: r2.geometry, used: used)
                    let score1 = overlap1 * 10.0 + (r1.distance / 1000.0) * 0.05
                    let score2 = overlap2 * 10.0 + (r2.distance / 1000.0) * 0.05
                    return score1 < score2
                } ?? routes.first!

                let selectedOverlap = overlapScore(candidate: bestRoute.geometry, used: used)

                if attempt == 0 && selectedOverlap > 0.25 {
                    let segmentBearing = calculateBearing(from: currentStart, to: currentEnd)
                    let perp = (segmentBearing + 90).truncatingRemainder(dividingBy: 360)
                    currentEnd = calculateDestination(start: end, bearing: perp, distance: 30.0)
                    print("[RoutingVM] Segment \(segmentIndex): high overlap (\(String(format: "%.1f", selectedOverlap * 100))%), retrying with jittered endpoint")
                    continue
                }

                print("[RoutingVM] Segment \(segmentIndex): \(Int(bestRoute.distance))m, overlap=\(String(format: "%.1f", selectedOverlap * 100))%")
                return bestRoute
            } catch {
                if attempt < 2 {
                    print("[RoutingVM] Error: \(error), retrying (attempt \(attempt + 1)/3)")
                    continue
                }
                throw error
            }
        }

        throw NSError(domain: "RoutingViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find acceptable route after 3 attempts"])
    }

    // MARK: - Waypoint Generation
    private func generateCircularWaypointPattern(userLocation: CLLocationCoordinate2D, viaPoint: CLLocationCoordinate2D, desiredDistance: Double) -> [CLLocationCoordinate2D] {
        var waypoints = [CLLocationCoordinate2D]()

        let centerlineBearing = calculateBearing(from: userLocation, to: viaPoint)
        let distanceToDestination = calculateHaversineDistance(from: userLocation, to: viaPoint)

        let deviationAngle = 45.0
        let deviationDistance = 100.0

        let targetWaypointDistance = desiredDistance * 0.65

        let numZigzags: Int = {
            switch desiredDistance {
            case ..<1500: return 1
            case 1500..<3000: return 2
            case 3000..<5000: return 3
            default: return 4
            }
        }()

        var currentPosition = userLocation
        var isLeftTurn = true

        print("[RoutingVM] Generating zigzag route: desiredDistance=\(Int(desiredDistance))m, waypoints=\(numZigzags) (distance-scaled), deviation=\(Int(deviationDistance))m at \(Int(deviationAngle))°")

        for i in 0..<numZigzags {
            let deviationDirection = isLeftTurn ? deviationAngle : -deviationAngle
            let waypointBearing = (centerlineBearing + deviationDirection).truncatingRemainder(dividingBy: 360)

            let progressAlongCenterline = Double(i + 1) / Double(numZigzags)
            let distanceAlongCenterline = distanceToDestination * progressAlongCenterline * 0.8

            let centerlinePoint = calculateDestination(start: userLocation, bearing: centerlineBearing, distance: distanceAlongCenterline)
            let waypoint = calculateDestination(start: centerlinePoint, bearing: waypointBearing, distance: deviationDistance)

            waypoints.append(waypoint)
            currentPosition = waypoint
            isLeftTurn.toggle()

            print("[RoutingVM]   Zigzag \(i+1): \(isLeftTurn ? "RIGHT" : "LEFT") deviation at \(Int(distanceAlongCenterline))m along centerline")
        }

        print("[RoutingVM] Generated \(waypoints.count) zigzag waypoints for \(Int(desiredDistance))m walk")

        return waypoints
    }

    private func generateSimplifiedWaypoints(userLocation: CLLocationCoordinate2D, viaPoint: CLLocationCoordinate2D, desiredDistance: Double) -> [CLLocationCoordinate2D] {
        print("[RoutingVM] Generating simplified waypoints (fallback level 2)")

        let bearing = calculateBearing(from: userLocation, to: viaPoint)
        let distance = calculateHaversineDistance(from: userLocation, to: viaPoint)

        var waypoints = [CLLocationCoordinate2D]()

        let midpoint = calculateDestination(start: userLocation, bearing: bearing, distance: distance * 0.5)
        let offset = calculateDestination(start: midpoint, bearing: (bearing + 90).truncatingRemainder(dividingBy: 360), distance: 80.0)
        waypoints.append(offset)

        waypoints.append(viaPoint)

        print("[RoutingVM] Simplified route: \(waypoints.count) waypoints")
        return waypoints
    }

    private func generateOutAndBackWaypoints(userLocation: CLLocationCoordinate2D, viaPoint: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        print("[RoutingVM] Generating out-and-back waypoints (fallback level 4)")

        let bearing = calculateBearing(from: userLocation, to: viaPoint)
        let distance = calculateHaversineDistance(from: userLocation, to: viaPoint)

        let destination = calculateDestination(start: userLocation, bearing: bearing, distance: distance * 0.5)

        return [destination]
    }

    // MARK: - POI Insertion
    private func insertPoisIntoPentagon(origin: CLLocationCoordinate2D, pentagonWaypoints: [CLLocationCoordinate2D], poisToInsert: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        if poisToInsert.isEmpty {
            return pentagonWaypoints
        }

        var result = [CLLocationCoordinate2D]()
        var poisByEdge = [Int: [CLLocationCoordinate2D]]()

        for poi in poisToInsert {
            var closestEdge = 0
            var minDistance = Double.greatestFiniteMagnitude

            for i in pentagonWaypoints.indices {
                let edgeStart = i == 0 ? origin : pentagonWaypoints[i - 1]
                let edgeEnd = pentagonWaypoints[i]

                let distance = distanceToLineSegment(point: poi, lineStart: edgeStart, lineEnd: edgeEnd)

                if distance < minDistance {
                    minDistance = distance
                    closestEdge = i
                }
            }

            if poisByEdge[closestEdge] == nil {
                poisByEdge[closestEdge] = []
            }
            poisByEdge[closestEdge]?.append(poi)
        }

        for (index, pentagonPoint) in pentagonWaypoints.enumerated() {
            if let edgePois = poisByEdge[index] {
                result.append(contentsOf: edgePois)
                print("[RoutingVM] Inserted \(edgePois.count) POIs before pentagon point \(index)")
            }
            result.append(pentagonPoint)
        }

        print("[RoutingVM] Combined waypoints: \(pentagonWaypoints.count) pentagon + \(poisToInsert.count) POIs = \(result.count) total")
        return result
    }

    private func distanceToLineSegment(point: CLLocationCoordinate2D, lineStart: CLLocationCoordinate2D, lineEnd: CLLocationCoordinate2D) -> Double {
        let distanceToStart = calculateHaversineDistance(from: point, to: lineStart)
        let distanceToEnd = calculateHaversineDistance(from: point, to: lineEnd)
        return min(distanceToStart, distanceToEnd)
    }

    // MARK: - U-turn Smoothing
    private func smoothUturns(points: inout [CLLocationCoordinate2D], minAngleDeg: Int = 140, jitterMeters: Double = 40.0) {
        var i = 1
        while i < points.count - 1 {
            let a = points[i - 1]
            let b = points[i]
            let c = points[i + 1]
            let ang = angleAtB(a: a, b: b, c: c)
            if ang > Double(minAngleDeg) {
                let bearing = calculateBearing(from: a, to: b)
                let perp = (bearing + 90).truncatingRemainder(dividingBy: 360)
                points[i] = calculateDestination(start: b, bearing: perp, distance: jitterMeters)
                print("[RoutingVM] Smoothed U-turn at waypoint \(i): angle=\(Int(ang))° -> nudged \(Int(jitterMeters))m perpendicular")
            }
            i += 1
        }
    }

    private func angleAtB(a: CLLocationCoordinate2D, b: CLLocationCoordinate2D, c: CLLocationCoordinate2D) -> Double {
        let ab = calculateBearing(from: b, to: a)
        let cb = calculateBearing(from: b, to: c)
        let diff = abs((ab - cb + 180).truncatingRemainder(dividingBy: 360) - 180)
        return diff
    }

    // MARK: - Overlap Detection
    private func overlapScore(candidate: String, used: [CLLocationCoordinate2D]) -> Double {
        var grid = Set<Int64>()

        func key(_ p: CLLocationCoordinate2D) -> Int64 {
            let kx = Int64(floor(p.latitude * 5000))
            let ky = Int64(floor(p.longitude * 5000))
            return (kx << 32) ^ ky
        }

        for coord in used {
            grid.insert(key(coord))
        }

        let candPts = decodePolyline(encoded: candidate)
        var hits = 0
        for p in candPts {
            if grid.contains(key(p)) {
                hits += 1
            }
        }
        return Double(hits) / Double(max(candPts.count, 1))
    }

    private func calculateRouteOverlap(route: Route) -> Double {
        let allPoints = decodePolyline(encoded: route.overviewPolyline)

        if allPoints.count < 10 { return 0.0 }

        var overlapCount = 0
        var totalSegments = 0

        for i in 0..<(allPoints.count - 1) {
            totalSegments += 1
            let segment1Start = allPoints[i]
            guard let segment1End = allPoints[safe: i + 1] else { continue }

            for j in (i + 5)..<min(allPoints.count - 1, i + 30) {
                let segment2Start = allPoints[j]
                guard let segment2End = allPoints[safe: j + 1] else { continue }

                let dist1 = calculateHaversineDistance(from: segment1Start, to: segment2Start)
                let dist2 = calculateHaversineDistance(from: segment1End, to: segment2End)

                if dist1 < 50 && dist2 < 50 {
                    let bearing1 = calculateBearing(from: segment1Start, to: segment1End)
                    let bearing2 = calculateBearing(from: segment2Start, to: segment2End)
                    let bearingDiff = abs((bearing1 - bearing2 + 180).truncatingRemainder(dividingBy: 360) - 180)

                    if bearingDiff > 150 {
                        overlapCount += 1
                        break
                    }
                }
            }
        }

        return (Double(overlapCount) / Double(totalSegments)) * 100.0
    }

    // MARK: - Geographic Calculations
    private func calculateHaversineDistance(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let earthRadiusKm = 6371.0

        let dLat = (destination.latitude - origin.latitude).toRadians()
        let dLng = (destination.longitude - origin.longitude).toRadians()

        let originLat = origin.latitude.toRadians()
        let destLat = destination.latitude.toRadians()

        let a = sin(dLat / 2) * sin(dLat / 2) +
                sin(dLng / 2) * sin(dLng / 2) * cos(originLat) * cos(destLat)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        let distanceKm = earthRadiusKm * c
        return distanceKm * 1000
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.toRadians()
        let lat2 = to.latitude.toRadians()
        let dLng = (to.longitude - from.longitude).toRadians()

        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)

        let bearing = atan2(y, x).toDegrees()
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    private func calculateDestination(start: CLLocationCoordinate2D, bearing: Double, distance: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0
        let bearingRad = bearing.toRadians()
        let lat1 = start.latitude.toRadians()
        let lng1 = start.longitude.toRadians()

        let lat2 = asin(
            sin(lat1) * cos(distance / earthRadius) +
            cos(lat1) * sin(distance / earthRadius) * cos(bearingRad)
        )

        let lng2 = lng1 + atan2(
            sin(bearingRad) * sin(distance / earthRadius) * cos(lat1),
            cos(distance / earthRadius) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(latitude: lat2.toDegrees(), longitude: lng2.toDegrees())
    }

    // MARK: - Polyline Encoding/Decoding
    private func decodePolyline(encoded: String) -> [CLLocationCoordinate2D] {
        var poly = [CLLocationCoordinate2D]()
        var index = encoded.startIndex
        let len = encoded.count
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

    private func encodePolyline(points: [CLLocationCoordinate2D]) -> String {
        var result = ""
        var prevLat = 0
        var prevLng = 0

        for point in points {
            let lat = Int(point.latitude * 1E5)
            let lng = Int(point.longitude * 1E5)

            let dLat = lat - prevLat
            let dLng = lng - prevLng

            encodeValue(value: dLat, result: &result)
            encodeValue(value: dLng, result: &result)

            prevLat = lat
            prevLng = lng
        }

        return result
    }

    private func encodeValue(value: Int, result: inout String) {
        var v = value < 0 ? ~(value << 1) : (value << 1)
        while v >= 0x20 {
            result.append(Character(UnicodeScalar((0x20 | (v & 0x1f)) + 63)!))
            v >>= 5
        }
        result.append(Character(UnicodeScalar(v + 63)!))
    }

    // MARK: - Route Conversion
    private func convertOsrmToRoute(osrmRoute: OsrmRoute) -> Route {
        let legs = osrmRoute.legs.map { osrmLeg -> RouteLeg in
            let steps = osrmLeg.steps.map { osrmStep -> RouteStep in
                let stepPoints = decodePolyline(encoded: osrmStep.geometry)
                let startLoc = stepPoints.first ?? CLLocationCoordinate2D()
                let endLoc = stepPoints.last ?? CLLocationCoordinate2D()

                return RouteStep(
                    htmlInstructions: osrmStep.name.isEmpty ? "Continue" : osrmStep.name,
                    distance: Distance(value: Int(osrmStep.distance), text: formatDistance(osrmStep.distance)),
                    duration: Duration(value: Int(osrmStep.duration), text: formatDuration(osrmStep.duration)),
                    startLocation: startLoc,
                    endLocation: endLoc,
                    polyline: osrmStep.geometry,
                    travelMode: "WALKING",
                    maneuver: nil
                )
            }

            let legStartLoc = steps.first?.startLocation ?? CLLocationCoordinate2D()
            let legEndLoc = steps.last?.endLocation ?? CLLocationCoordinate2D()

            return RouteLeg(
                distance: Distance(value: Int(osrmLeg.distance), text: formatDistance(osrmLeg.distance)),
                duration: Duration(value: Int(osrmLeg.duration), text: formatDuration(osrmLeg.duration)),
                startLocation: legStartLoc,
                endLocation: legEndLoc,
                steps: steps
            )
        }

        return Route(
            summary: "OSRM Walking Route",
            overviewPolyline: osrmRoute.geometry,
            legs: legs,
            warnings: []
        )
    }

    // MARK: - Formatting
    private func formatDistance(_ distanceMeters: Double) -> String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters)) m"
        } else {
            return String(format: "%.1f km", distanceMeters / 1000)
        }
    }

    private func formatDuration(_ durationSeconds: Double) -> String {
        let seconds = Int(durationSeconds)
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

    private func calculateETA(_ distanceMeters: Double) -> String {
        let walkingSpeedMps = 1.4
        let durationSeconds = Int(distanceMeters / walkingSpeedMps)

        if durationSeconds < 60 {
            return "< 1 min"
        } else if durationSeconds < 3600 {
            return "\(durationSeconds / 60) min"
        } else {
            let hours = durationSeconds / 3600
            let mins = (durationSeconds % 3600) / 60
            return mins > 0 ? "\(hours) hr \(mins) min" : "\(hours) hr"
        }
    }

    private func updatePreviewWithRoute(preview: RoutePreview, route: Route) {
        let totalDurationSeconds = route.legs.reduce(0) { $0 + $1.duration.value }
        let eta = totalDurationSeconds > 0 ? formatDuration(Double(totalDurationSeconds)) : calculateETA(preview.straightLineDistance)

        routingState = .previewReady(RoutePreview(
            destination: preview.destination,
            destinationName: preview.destinationName,
            straightLineDistance: preview.straightLineDistance,
            eta: eta,
            route: route,
            isLoading: false,
            routeType: preview.routeType,
            pathPreference: preview.pathPreference,
            poiList: preview.poiList
        ))
    }
}

// MARK: - Route Cache
class RouteCache {
    private struct CacheEntry {
        let route: Route
        let timestamp: Date
    }

    private var cache = [String: CacheEntry]()
    private let lock = NSLock()
    private let cacheTTL: TimeInterval = 5 * 60
    private let maxCacheSize = 10
    private let geohashPrecision = 5

    func key(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) -> String {
        let originHash = geohash(latitude: origin.latitude, longitude: origin.longitude, precision: geohashPrecision)
        let destHash = geohash(latitude: destination.latitude, longitude: destination.longitude, precision: geohashPrecision)
        return "\(originHash)_\(destHash)"
    }

    func get(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) -> Route? {
        lock.lock()
        defer { lock.unlock() }

        let cacheKey = key(origin: origin, destination: destination)

        guard let entry = cache[cacheKey] else {
            print("[RouteCache] MISS: \(cacheKey)")
            return nil
        }

        let now = Date()
        let isExpired = now.timeIntervalSince(entry.timestamp) > cacheTTL

        if isExpired {
            cache.removeValue(forKey: cacheKey)
            print("[RouteCache] MISS (expired): \(cacheKey)")
            return nil
        }

        print("[RouteCache] HIT: \(cacheKey)")
        return entry.route
    }

    func put(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, route: Route) {
        lock.lock()
        defer { lock.unlock() }

        let cacheKey = key(origin: origin, destination: destination)

        if cache.count >= maxCacheSize && cache[cacheKey] == nil {
            if let oldestKey = cache.keys.first {
                cache.removeValue(forKey: oldestKey)
                print("[RouteCache] EVICT: \(oldestKey)")
            }
        }

        cache[cacheKey] = CacheEntry(route: route, timestamp: Date())
        print("[RouteCache] PUT: \(cacheKey)")
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        print("[RouteCache] CLEAR")
    }

    private func geohash(latitude: Double, longitude: Double, precision: Int) -> String {
        let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var hash = ""
        var bits = 0
        var bit = 0
        var even = true

        while hash.count < precision {
            if even {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude > mid {
                    bit |= (1 << (4 - bits))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude > mid {
                    bit |= (1 << (4 - bits))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }

            even = !even
            bits += 1

            if bits == 5 {
                hash.append(base32[bit])
                bits = 0
                bit = 0
            }
        }

        return hash
    }
}

// MARK: - Extensions
extension Double {
    fileprivate func toRadians() -> Double {
        return self * .pi / 180
    }

    fileprivate func toDegrees() -> Double {
        return self * 180 / .pi
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
