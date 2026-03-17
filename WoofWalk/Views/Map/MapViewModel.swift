import SwiftUI
import MapKit
import Combine
import CoreLocation

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

        poiService.getPoisNearby(center: queryCenter, radiusKm: 5.0)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("[MapViewModel] Failed to load POIs: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] pois in
                    self?.pois = pois
                    print("[MapViewModel] Loaded \(pois.count) POIs from Firestore")
                }
            )
            .store(in: &cancellables)
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
        walkTimer?.invalidate()
        walkTimer = nil
        walkStartTime = nil

        Task {
            do {
                try await saveWalkSession()
            } catch {
                print("Failed to save walk session: \(error)")
            }
        }
    }

    private func saveWalkSession() async throws {
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
