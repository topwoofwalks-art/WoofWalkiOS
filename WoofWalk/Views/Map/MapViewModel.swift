import SwiftUI
import MapKit
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class MapViewModel: ObservableObject {
    @Published var pois: [POI] = []
    @Published var filteredPOIs: [POI] = []
    @Published var selectedPOITypes: Set<POI.POIType> = Set(POI.POIType.allCases)
    @Published var walkPolyline: [CLLocationCoordinate2D] = []
    @Published var routePolyline: [CLLocationCoordinate2D] = []
    @Published var activeBagDrops: [PooBagDrop] = []
    @Published var publicDogs: [PublicDog] = []
    @Published var lostDogs: [LostDog] = []
    @Published var searchResults: [SearchResult] = []
    @Published var cameraMode: CameraMode = .free
    @Published var mapStyle: WoofWalkMapStyle = .hybrid
    @Published var walkDistance: Double = 0
    @Published var walkDuration: TimeInterval = 0
    @Published var showLivestockOverlays: Bool = true
    @Published var showWalkingPathOverlays: Bool = true
    @Published var isInDrawingMode: Bool = false
    @Published var hazardReports: [HazardReport] = []
    @Published var trailConditions: [TrailCondition] = []
    @Published var offLeadZones: [OffLeadZone] = []

    // MARK: - Planning Mode State
    @Published var planningWaypoints: [CLLocationCoordinate2D] = []
    @Published var plannedRouteDistance: Double = 0 // meters
    @Published var plannedRouteDuration: Int = 0 // seconds
    @Published var isLoopClosed: Bool = false
    @Published var closingSegmentPreview: [CLLocationCoordinate2D] = []
    @Published var planningSegmentPolylines: [[CLLocationCoordinate2D]] = [] // detailed route per segment
    @Published var isFetchingRoute: Bool = false
    @Published var useFootpathRouting: Bool = true // true = walking mode via OSRM

    private static let walkingSpeedKmh: Double = 5.0
    private let osrmBaseURL = "https://router.project-osrm.org"

    private var cancellables = Set<AnyCancellable>()
    private var walkStartTime: Date?
    private var walkTimer: Timer?
    private let poiService = PoiServiceRepository.shared

    enum CameraMode {
        case free
        case follow
        case overview
        case tilt

        var icon: String {
            switch self {
            case .free: return "hand.point.up.left.fill"
            case .follow: return "location.fill"
            case .overview: return "map.fill"
            case .tilt: return "camera.fill"
            }
        }
    }

    var cameraModeIcon: String {
        cameraMode.icon
    }

    init() {
        setupFilterObserver()
    }

    private func setupFilterObserver() {
        $selectedPOITypes
            .combineLatest($pois)
            .map { types, pois in
                pois.filter { types.contains($0.poiType) }
            }
            .assign(to: &$filteredPOIs)
    }

    func loadPOIs(near center: CLLocationCoordinate2D? = nil) {
        let queryCenter = center ?? CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)

        // Load from Firestore
        poiService.getPoisNearby(center: queryCenter, radiusKm: 5.0)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("[MapViewModel] Failed to load POIs from Firestore: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] firestorePois in
                    guard let self = self else { return }
                    let existingOsmPois = self.pois.filter { $0.id.hasPrefix("osm_") }
                    self.pois = firestorePois + existingOsmPois
                    print("[MapViewModel] Loaded \(firestorePois.count) POIs from Firestore, \(existingOsmPois.count) OSM POIs retained")
                }
            )
            .store(in: &cancellables)

        // Load from Overpass/OSM (with caching)
        loadOverpassPOIs(near: queryCenter)
    }

    private func loadOverpassPOIs(near center: CLLocationCoordinate2D) {
        Task {
            do {
                let service = PoiOverpassService()
                let query = PoiOverpassService.buildDogFriendlyQuery(
                    lat: center.latitude,
                    lng: center.longitude,
                    radiusMeters: 2000
                )
                let response = try await service.query(query)
                let osmPois = response.elements.map { element in
                    Poi(
                        id: "osm_\(element.id)",
                        type: PoiOverpassService.mapOsmTypeToPoiType(tags: element.tags),
                        title: element.tags?["name"] ?? "",
                        desc: "",
                        lat: element.lat,
                        lng: element.lon
                    )
                }
                let firestorePois = self.pois.filter { !$0.id.hasPrefix("osm_") }
                self.pois = firestorePois + osmPois
                print("[MapViewModel] Loaded \(osmPois.count) POIs from Overpass/OSM")
            } catch {
                print("[MapViewModel] Failed to load Overpass POIs: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Load Hazard Reports from Firestore

    func loadHazardReports() {
        let db = Firestore.firestore()
        db.collection("hazardReports")
            .whereField("status", isEqualTo: "active")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else {
                    print("[MapViewModel] Failed to load hazards: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                self?.hazardReports = docs.compactMap { doc -> HazardReport? in
                    try? doc.data(as: HazardReport.self)
                }
                print("[MapViewModel] Loaded \(self?.hazardReports.count ?? 0) hazard reports")

                // Register geofences for nearby hazards
                if let hazards = self?.hazardReports, !hazards.isEmpty {
                    let hazardPois = hazards.map { hazard in
                        Poi(type: "HAZARD", title: hazard.hazardType.displayName, desc: hazard.description,
                            lat: hazard.lat, lng: hazard.lng)
                    }
                    // Use first hazard location as approximate user location for filtering
                    if let first = hazards.first {
                        let approxLocation = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lng)
                        let _ = GeofenceManager.shared.registerGeofences(
                            pois: hazardPois, userLocation: approxLocation
                        )
                    }
                }
            }
    }

    // MARK: - Load Trail Conditions from Firestore

    func loadTrailConditions() {
        let db = Firestore.firestore()
        db.collection("trailConditions")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else {
                    print("[MapViewModel] Failed to load trail conditions: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                self?.trailConditions = docs.compactMap { doc -> TrailCondition? in
                    try? doc.data(as: TrailCondition.self)
                }
                print("[MapViewModel] Loaded \(self?.trailConditions.count ?? 0) trail conditions")
            }
    }

    // MARK: - Load Public Dogs from Firestore

    func loadPublicDogs() {
        let db = Firestore.firestore()
        db.collection("publicDogs")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                self?.publicDogs = docs.compactMap { doc -> PublicDog? in
                    let data = doc.data()
                    guard let lat = data["lat"] as? Double,
                          let lng = data["lng"] as? Double else { return nil }
                    return PublicDog(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "Unknown",
                        breed: data["breed"] as? String ?? "",
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                        isNervous: data["isNervous"] as? Bool ?? false,
                        warningNote: data["warningNote"] as? String,
                        ownerName: data["ownerName"] as? String ?? "",
                        photoURL: (data["photoUrl"] as? String).flatMap { URL(string: $0) }
                    )
                }
                print("[MapViewModel] Loaded \(self?.publicDogs.count ?? 0) public dogs")
            }
    }

    // MARK: - Load Lost Dogs for Map

    func loadLostDogs() {
        let db = Firestore.firestore()
        db.collection("lostDogs")
            .whereField("status", isEqualTo: "LOST")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                self?.lostDogs = docs.compactMap { doc -> LostDog? in
                    let data = doc.data()
                    guard let lat = data["lat"] as? Double,
                          let lng = data["lng"] as? Double else { return nil }
                    return LostDog(
                        id: doc.documentID,
                        name: data["dogName"] as? String ?? "Unknown",
                        breed: data["dogBreed"] as? String ?? "",
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                        description: data["description"] as? String ?? "",
                        locationDescription: data["lastSeenLocation"] as? String ?? "",
                        reporterName: data["reporterName"] as? String ?? "",
                        reporterPhone: data["reporterPhone"] as? String,
                        photoURL: (data["dogPhotoUrl"] as? String).flatMap { URL(string: $0) },
                        reportedAt: (data["reportedAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
                print("[MapViewModel] Loaded \(self?.lostDogs.count ?? 0) lost dogs")
            }
    }

    func togglePOIType(_ type: POI.POIType) {
        if selectedPOITypes.contains(type) {
            selectedPOITypes.remove(type)
        } else {
            selectedPOITypes.insert(type)
        }
    }

    func clearFilters() {
        selectedPOITypes = Set(POI.POIType.allCases)
    }

    func addPOI(type: POI.POIType, at coordinate: CLLocationCoordinate2D) {
        let newPOI = POI(
            type: type.rawValue,
            title: "New \(type.displayName)",
            desc: "User added POI",
            lat: coordinate.latitude,
            lng: coordinate.longitude
        )
        pois.append(newPOI)

        Task {
            do {
                let docId = try await poiService.createPoi(newPOI)
                print("[MapViewModel] POI saved: \(docId)")
            } catch {
                print("[MapViewModel] Failed to save POI: \(error.localizedDescription)")
            }
        }
    }

    func removePOI(_ poi: POI) {
        pois.removeAll { $0.id == poi.id }
    }

    func addPooBagDrop(at coordinate: CLLocationCoordinate2D) {
        let drop = PooBagDrop(
            id: UUID().uuidString,
            coordinate: coordinate,
            droppedAt: Date(),
            notes: nil
        )
        activeBagDrops.append(drop)

        Task {
            do {
                try await savePooBagToAPI(drop)
            } catch {
                print("Failed to save poo bag drop: \(error)")
            }
        }
    }

    private func savePooBagToAPI(_ drop: PooBagDrop) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "userId": userId,
            "lat": drop.coordinate.latitude,
            "lng": drop.coordinate.longitude,
            "droppedAt": Timestamp(date: drop.droppedAt),
            "notes": drop.notes ?? "",
            "collected": false
        ]
        try await db.collection("pooBagDrops").document(drop.id).setData(data)
        print("[MapViewModel] Poo bag drop saved: \(drop.id)")
    }

    func startWalkTracking() {
        walkStartTime = Date()
        walkDistance = 0
        walkPolyline = []

        walkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.walkStartTime else { return }
            self.walkDuration = Date().timeIntervalSince(startTime)
        }
    }

    func stopWalkTracking() {
        let startTime = walkStartTime
        let distance = walkDistance
        let duration = walkDuration
        let polylineCoords = walkPolyline

        walkTimer?.invalidate()
        walkTimer = nil
        walkStartTime = nil

        Task {
            do {
                try await saveWalkSession(
                    startTime: startTime,
                    distanceMeters: distance,
                    durationSec: Int(duration),
                    polylineCoords: polylineCoords
                )
            } catch {
                print("[MapViewModel] Failed to save walk session: \(error)")
            }
        }
    }

    private func saveWalkSession(
        startTime: Date?,
        distanceMeters: Double,
        durationSec: Int,
        polylineCoords: [CLLocationCoordinate2D]
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[MapViewModel] Cannot save walk: user not authenticated")
            return
        }

        guard distanceMeters > 0 || durationSec > 0 else {
            print("[MapViewModel] Skipping save: no distance or duration recorded")
            return
        }

        let now = Date()
        let start = startTime ?? now.addingTimeInterval(-TimeInterval(durationSec))
        let walkId = "\(userId)_\(Int(start.timeIntervalSince1970 * 1000))"

        let trackPoints: [TrackPoint] = polylineCoords.enumerated().map { index, coord in
            let pointTime = start.timeIntervalSince1970 * 1000 +
                Double(index) * (Double(durationSec) * 1000.0 / max(Double(polylineCoords.count), 1.0))
            return TrackPoint(
                t: Int64(pointTime),
                lat: coord.latitude,
                lng: coord.longitude,
                acc: 0.0
            )
        }

        let polyline = PolylineEncoder.encode(coordinates: polylineCoords)

        let walkData: [String: Any] = [
            "userId": userId,
            "startedAt": Timestamp(date: start),
            "endedAt": Timestamp(date: now),
            "distanceMeters": distanceMeters,
            "durationSec": durationSec,
            "track": trackPoints.map { [
                "t": $0.t,
                "lat": $0.lat,
                "lng": $0.lng,
                "acc": $0.acc
            ] as [String: Any] },
            "polyline": polyline,
            "dogIds": [String]()
        ]

        let db = Firestore.firestore()
        try await db.collection("users").document(userId)
            .collection("walks").document(walkId)
            .setData(walkData)

        print("[MapViewModel] Walk saved to Firestore: \(walkId), distance=\(distanceMeters)m, duration=\(durationSec)s")
    }

    func updateWalkPolyline(with coordinate: CLLocationCoordinate2D) {
        if let last = walkPolyline.last {
            let distance = CLLocation(
                latitude: last.latitude,
                longitude: last.longitude
            ).distance(
                from: CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
            walkDistance += distance
        }
        walkPolyline.append(coordinate)
    }

    func cycleCameraMode() {
        switch cameraMode {
        case .free:
            cameraMode = .follow
        case .follow:
            cameraMode = .overview
        case .overview:
            cameraMode = .tilt
        case .tilt:
            cameraMode = .follow
        }
    }

    func searchLocation(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let response = response else {
                print("Search error: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            self?.searchResults = response.mapItems.map { item in
                SearchResult(
                    id: UUID().uuidString,
                    title: item.name ?? "",
                    subtitle: item.placemark.title ?? "",
                    coordinate: item.placemark.coordinate
                )
            }
        }
    }

    func selectSearchResult(_ result: SearchResult) {
        routePolyline = []
    }

    func navigateToPOI(_ poi: POI) {
    }

    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let route = response?.routes.first else {
                print("Route calculation error: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            self?.routePolyline = route.polyline.coordinates
        }
    }

    func generateCircularRoute(from origin: CLLocationCoordinate2D, via viaPoint: CLLocationCoordinate2D) {
        // Simple circular route: origin -> via -> origin
        routePolyline = [origin, viaPoint, origin]
    }

    func onCameraChange(_ region: MKCoordinateRegion) {
    }

    func convertScreenToCoordinate(_ point: CGPoint) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    func toggleLivestockOverlays() {
        showLivestockOverlays.toggle()
    }

    func toggleWalkingPathOverlays() {
        showWalkingPathOverlays.toggle()
    }

    func enterDrawingMode() {
        isInDrawingMode = true
    }

    func exitDrawingMode() {
        isInDrawingMode = false
    }

    // MARK: - Planning Mode

    func addPlanningWaypoint(_ coordinate: CLLocationCoordinate2D) {
        let previousWaypoint = planningWaypoints.last
        planningWaypoints.append(coordinate)
        isLoopClosed = false

        // Fetch routed segment between previous waypoint and this one
        // Segment index is waypoints.count - 2 (the segment connecting the penultimate to the last)
        if let from = previousWaypoint {
            let segmentIndex = planningWaypoints.count - 2
            fetchRoutedSegment(from: from, to: coordinate, segmentIndex: segmentIndex)
        }

        updatePlannedRouteStats()

        // Auto-preview closing segment when 3+ waypoints
        if planningWaypoints.count >= 3 {
            updateClosingSegmentPreview()
        } else {
            closingSegmentPreview = []
        }
    }

    func removeLastPlanningWaypoint() {
        guard !planningWaypoints.isEmpty else { return }
        planningWaypoints.removeLast()
        if !planningSegmentPolylines.isEmpty {
            planningSegmentPolylines.removeLast()
        }
        isLoopClosed = false

        updatePlannedRouteStats()

        if planningWaypoints.count >= 3 {
            updateClosingSegmentPreview()
        } else {
            closingSegmentPreview = []
        }
    }

    func clearAllPlanningWaypoints() {
        planningWaypoints = []
        planningSegmentPolylines = []
        plannedRouteDistance = 0
        plannedRouteDuration = 0
        isLoopClosed = false
        closingSegmentPreview = []
    }

    /// Close the loop by connecting the last waypoint back to the first.
    /// Requires 3+ waypoints and the loop must not already be closed.
    func closeLoop() {
        guard planningWaypoints.count >= 3, !isLoopClosed else { return }
        isLoopClosed = true
        closingSegmentPreview = [] // No longer a preview - it's committed
        updatePlannedRouteStats()
    }

    private func updateClosingSegmentPreview() {
        guard planningWaypoints.count >= 3, !isLoopClosed else {
            closingSegmentPreview = []
            return
        }
        // Straight-line preview from last waypoint to first
        closingSegmentPreview = [planningWaypoints.last!, planningWaypoints.first!]
    }

    private func updatePlannedRouteStats() {
        let waypoints = planningWaypoints
        guard waypoints.count >= 2 else {
            plannedRouteDistance = 0
            plannedRouteDuration = 0
            return
        }

        var totalDistance: Double = 0

        // Use routed segment distances where available, fall back to Haversine
        for i in 0..<(waypoints.count - 1) {
            if i < planningSegmentPolylines.count, planningSegmentPolylines[i].count >= 2 {
                // Sum the routed polyline segment distances
                let polyline = planningSegmentPolylines[i]
                for j in 0..<(polyline.count - 1) {
                    totalDistance += Self.haversineDistance(from: polyline[j], to: polyline[j + 1])
                }
            } else {
                totalDistance += Self.haversineDistance(from: waypoints[i], to: waypoints[i + 1])
            }
        }

        // Add closing segment distance (preview or committed)
        if isLoopClosed, waypoints.count >= 3 {
            totalDistance += Self.haversineDistance(from: waypoints.last!, to: waypoints.first!)
        }

        plannedRouteDistance = totalDistance
        plannedRouteDuration = Self.estimateWalkDuration(distanceMeters: totalDistance)
    }

    // MARK: - Distance Calculation

    /// Haversine formula for distance between two coordinates in meters.
    static func haversineDistance(from c1: CLLocationCoordinate2D, to c2: CLLocationCoordinate2D) -> Double {
        let earthRadiusMeters: Double = 6_371_000.0
        let dLat = (c2.latitude - c1.latitude) * .pi / 180.0
        let dLng = (c2.longitude - c1.longitude) * .pi / 180.0
        let lat1 = c1.latitude * .pi / 180.0
        let lat2 = c2.latitude * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }

    /// Estimate walk duration in seconds assuming average walking speed.
    static func estimateWalkDuration(distanceMeters: Double) -> Int {
        let distanceKm = distanceMeters / 1000.0
        let hours = distanceKm / walkingSpeedKmh
        return Int(hours * 3600)
    }

    // MARK: - Routed Segment Fetching (OSRM)

    /// Returns the combined detailed polyline for all planned segments.
    /// Falls back to straight lines between waypoints where no routed segment exists.
    var combinedPlanningPolyline: [CLLocationCoordinate2D] {
        guard planningWaypoints.count >= 2 else { return planningWaypoints }
        var result = [CLLocationCoordinate2D]()

        for i in 0..<(planningWaypoints.count - 1) {
            if i < planningSegmentPolylines.count, planningSegmentPolylines[i].count >= 2 {
                if result.isEmpty {
                    result.append(contentsOf: planningSegmentPolylines[i])
                } else {
                    result.append(contentsOf: planningSegmentPolylines[i].dropFirst())
                }
            } else {
                // Straight line fallback
                if result.isEmpty {
                    result.append(planningWaypoints[i])
                }
                result.append(planningWaypoints[i + 1])
            }
        }

        // If loop is closed, add closing segment (straight line for now)
        if isLoopClosed, planningWaypoints.count >= 3,
           let first = planningWaypoints.first {
            result.append(first)
        }

        return result
    }

    /// Fetch a walking route between two waypoints via OSRM.
    /// On success, stores the detailed polyline in planningSegmentPolylines and updates stats.
    /// On failure, falls back to straight-line (no polyline stored for that segment).
    private func fetchRoutedSegment(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, segmentIndex: Int) {
        guard useFootpathRouting else {
            // Straight-line mode: store empty array placeholder
            while planningSegmentPolylines.count <= segmentIndex {
                planningSegmentPolylines.append([])
            }
            return
        }

        isFetchingRoute = true

        Task {
            defer { isFetchingRoute = false }

            do {
                let coordinates = "\(from.longitude),\(from.latitude);\(to.longitude),\(to.latitude)"

                var urlComponents = URLComponents(string: "\(osrmBaseURL)/route/v1/foot/\(coordinates)")!
                urlComponents.queryItems = [
                    URLQueryItem(name: "overview", value: "full"),
                    URLQueryItem(name: "geometries", value: "polyline"),
                    URLQueryItem(name: "steps", value: "true")
                ]

                guard let url = urlComponents.url else {
                    print("[MapViewModel] Invalid OSRM URL")
                    ensureSegmentPlaceholder(at: segmentIndex)
                    return
                }

                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("[MapViewModel] OSRM HTTP error: \(httpResponse.statusCode)")
                    ensureSegmentPlaceholder(at: segmentIndex)
                    updatePlannedRouteStats()
                    return
                }

                let osrmResponse = try JSONDecoder().decode(OsrmRouteResponse.self, from: data)

                guard osrmResponse.code == "Ok",
                      let route = osrmResponse.routes?.first else {
                    print("[MapViewModel] OSRM: no route found, falling back to straight line")
                    ensureSegmentPlaceholder(at: segmentIndex)
                    updatePlannedRouteStats()
                    return
                }

                let polyline = decodePolyline(encoded: route.geometry)

                // Store the routed polyline at the correct index
                while planningSegmentPolylines.count <= segmentIndex {
                    planningSegmentPolylines.append([])
                }
                planningSegmentPolylines[segmentIndex] = polyline

                print("[MapViewModel] Routed segment \(segmentIndex): \(Int(route.distance))m, \(Int(route.duration))s, \(polyline.count) points")

                updatePlannedRouteStats()

            } catch {
                print("[MapViewModel] Failed to fetch routed segment: \(error.localizedDescription)")
                ensureSegmentPlaceholder(at: segmentIndex)
                updatePlannedRouteStats()
            }
        }
    }

    private func ensureSegmentPlaceholder(at index: Int) {
        while planningSegmentPolylines.count <= index {
            planningSegmentPolylines.append([])
        }
    }

    // MARK: - Polyline Decoding

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

struct SearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
