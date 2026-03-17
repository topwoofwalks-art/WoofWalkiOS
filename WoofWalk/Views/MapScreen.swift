import SwiftUI
import MapKit
import CoreLocation
import AVFoundation

struct MapScreen: View {
    @StateObject var mapViewModel = MapViewModel()
    @StateObject var routingViewModel = RoutingViewModel()
    @StateObject var guidanceViewModel = GuidanceViewModel()
    @StateObject var walkTrackingViewModel = WalkTrackingViewModel()
    @StateObject var pooBagDropViewModel = PooBagDropViewModel()
    @StateObject var locationManager = LocationManager()

    @State var showSearchBar = false
    @State var showFilterSheet = false
    @State var showPOIDetailSheet = false
    @State var selectedPOI: POI?
    @State var selectedBagDrop: PooBagDrop?
    @State var selectedPublicDog: PublicDog?
    @State var selectedLostDog: LostDog?
    @State var showPublicDogSheet = false
    @State var showLostDogSheet = false
    @State var showMapClickDialog = false
    @State var showDistancePickerDialog = false
    @State var showPOISelectionDialog = false
    @State var showCarOptionsDialog = false
    @State var showAppGuide = false
    @State var showWalkSummary = false
    @State var clickedLocation: CLLocationCoordinate2D?
    @State var isTorchOn = false
    @State var carLocation: CLLocationCoordinate2D?
    @State var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State var showRoutePreview = false
    @State var routePreview: RoutePreview?
    @State var completedDistance: Double = 0
    @State var completedDuration: Int = 0
    @State var mapStyle: WoofWalkMapStyle = .standard
    @State var isPlanningMode = false
    @State var planningWaypoints: [CLLocationCoordinate2D] = []
    @State var showBackgroundLocationPrompt = false
    @State var showRouteStartProximity = false
    @State var pendingRouteStart: CLLocationCoordinate2D?
    @State var showLivestockMode = false
    @State var showWalkingPaths = false
    @State var dismissedHazardIds: Set<String> = []
    @State var showTrailConditionSheet = false
    @State var showNearbyPubsSheet = false
    @State var showPubDetailSheet = false
    @State var selectedPub: POI?
    @State var showClusterSelectionSheet = false
    @State var selectedCluster: AnnotationCluster?
    @AppStorage("hasShownBackgroundLocationPrompt") var hasShownPrompt = false
    @AppStorage("walkStreak") var walkStreak: Int = 0

    var body: some View {
        mapContent
    }

    // MARK: - Main Map Content

    var mapContent: some View {
        ZStack {
            mapLayer
            controlsOverlay
            hazardAlertOverlay
            planningOverlay
        }
        .modifier(MapSheetModifiers(
            showSearchBar: $showSearchBar,
            showFilterSheet: $showFilterSheet,
            showPOIDetailSheet: $showPOIDetailSheet,
            showPublicDogSheet: $showPublicDogSheet,
            showLostDogSheet: $showLostDogSheet,
            showAppGuide: $showAppGuide,
            showBackgroundLocationPrompt: $showBackgroundLocationPrompt,
            selectedBagDrop: $selectedBagDrop,
            showRouteStartProximity: $showRouteStartProximity,
            selectedPOI: selectedPOI,
            selectedPublicDog: selectedPublicDog,
            selectedLostDog: selectedLostDog,
            pendingRouteStart: pendingRouteStart,
            mapViewModel: mapViewModel,
            locationManager: locationManager,
            walkTrackingViewModel: walkTrackingViewModel,
            routingViewModel: routingViewModel,
            pooBagDropViewModel: pooBagDropViewModel,
            callPhoneNumber: callPhoneNumber,
            startWalk: startWalk,
            onRouteStartProximityDismiss: {
                showRouteStartProximity = false
                pendingRouteStart = nil
            },
            onRouteStartNavigate: { start in
                if let userLoc = locationManager.location {
                    routingViewModel.generateCircularRoute(userLocation: userLoc, viaPoint: start)
                }
                showRouteStartProximity = false
            },
            onRouteStartAnyway: {
                showRouteStartProximity = false
                startWalk()
            }
        ))
        .modifier(MapAlertModifiers(
            showMapClickDialog: $showMapClickDialog,
            showCarOptionsDialog: $showCarOptionsDialog,
            showPOISelectionDialog: $showPOISelectionDialog,
            clickedLocation: clickedLocation,
            carLocation: carLocation,
            locationManager: locationManager,
            routingViewModel: routingViewModel,
            onWalkHere: { location in
                pendingRouteStart = location
                showRouteStartProximity = true
            },
            onClearClickedLocation: { clickedLocation = nil },
            onClearCarLocation: { carLocation = nil }
        ))
        .modifier(MapFullScreenModifiers(
            showWalkSummary: $showWalkSummary,
            completedDistance: completedDistance,
            completedDuration: completedDuration
        ))
        .sheet(isPresented: $showTrailConditionSheet) {
            TrailConditionSheet(
                userLocation: locationManager.location,
                onSubmit: { type, severity, note in
                    guard let location = locationManager.location else { return }
                    let condition = TrailCondition(
                        type: type.rawValue,
                        severity: severity,
                        note: note,
                        lat: location.latitude,
                        lng: location.longitude,
                        reportedBy: "",
                        voteUp: 0,
                        voteDown: 0
                    )
                    mapViewModel.trailConditions.append(condition)
                }
            )
        }
        .sheet(isPresented: $showNearbyPubsSheet) {
            NearbyPubsSheet(
                pubs: mapViewModel.filteredPOIs.filter { $0.poiType == .dogFriendlyPub },
                userLocation: locationManager.location,
                onSelect: { pub in
                    selectedPub = pub
                    showPubDetailSheet = true
                },
                onOpenInMaps: { pub in
                    openPubInMaps(pub)
                }
            )
        }
        .sheet(isPresented: $showPubDetailSheet) {
            if let pub = selectedPub {
                PubDetailSheet(
                    poi: pub,
                    userLocation: locationManager.location,
                    onNavigate: {
                        showPubDetailSheet = false
                        if let userLoc = locationManager.location {
                            routingViewModel.generateCircularRoute(
                                userLocation: userLoc,
                                viaPoint: pub.coordinate
                            )
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showClusterSelectionSheet) {
            if let cluster = selectedCluster {
                ClusterPoiSelectionSheet(
                    cluster: cluster,
                    userLocation: locationManager.location,
                    onSelectPoi: { poi in
                        selectedPOI = poi
                        showPOIDetailSheet = true
                    }
                )
            }
        }
        .onAppear {
            locationManager.startUpdatingLocation()
            mapViewModel.loadPOIs(near: locationManager.location)
        }
        .onChange(of: locationManager.location) { newLocation in
            if let location = newLocation {
                mapViewModel.updateWalkPolyline(with: location)
                walkTrackingViewModel.updateLocation(location)
            }
        }
    }

    // MARK: - Map Layer

    var mapAnnotations: [MapMarkerItem] {
        var items: [MapMarkerItem] = []

        // POIs
        for poi in mapViewModel.filteredPOIs {
            items.append(MapMarkerItem(
                id: "poi-\(poi.id)",
                coordinate: poi.coordinate,
                kind: .poi(poi)
            ))
        }

        // Poo bag drops
        for bag in mapViewModel.activeBagDrops {
            items.append(MapMarkerItem(
                id: "bag-\(bag.id)",
                coordinate: bag.coordinate,
                kind: .pooBag(bag)
            ))
        }

        // Public dogs
        for dog in mapViewModel.publicDogs {
            items.append(MapMarkerItem(
                id: "dog-\(dog.id)",
                coordinate: dog.coordinate,
                kind: .publicDog(dog)
            ))
        }

        // Lost dogs
        for dog in mapViewModel.lostDogs {
            items.append(MapMarkerItem(
                id: "lost-\(dog.id)",
                coordinate: dog.coordinate,
                kind: .lostDog(dog)
            ))
        }

        // Car location
        if let car = carLocation {
            items.append(MapMarkerItem(
                id: "car",
                coordinate: car,
                kind: .car
            ))
        }

        // Hazard reports
        items.append(contentsOf: hazardMarkerItems)

        // Trail conditions
        items.append(contentsOf: trailConditionMarkerItems)

        // Off-lead zone labels (center markers)
        for zone in mapViewModel.offLeadZones {
            items.append(MapMarkerItem(
                id: "zone-\(zone.id)",
                coordinate: zone.center,
                kind: .offLeadZoneLabel(zone)
            ))
        }

        return items
    }

    var mapLayer: some View {
        Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: mapAnnotations) { item in
            MapAnnotation(coordinate: item.coordinate) {
                switch item.kind {
                case .poi(let poi):
                    POIMarkerView(poi: poi)
                        .onTapGesture { handlePOITap(poi) }
                case .pooBag(let bag):
                    Image(systemName: "bag.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Circle().fill(.orange))
                        .shadow(radius: 3)
                        .onTapGesture { handleBagDropTap(bag) }
                case .publicDog(let dog):
                    Image(systemName: dog.isNervous ? "exclamationmark.triangle.fill" : "pawprint.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Circle().fill(dog.isNervous ? .orange : .blue))
                        .shadow(radius: 3)
                        .onTapGesture { handlePublicDogTap(dog) }
                case .lostDog(let dog):
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .padding(8)
                            .background(Circle().fill(.red))
                            .shadow(radius: 3)
                        Text("LOST")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .onTapGesture { handleLostDogTap(dog) }
                case .car:
                    Image(systemName: "car.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Circle().fill(.cyan))
                        .shadow(radius: 3)
                case .hazard(let hazard):
                    hazardMarkerView(for: hazard)
                case .trailCondition(let condition):
                    trailConditionMarkerView(for: condition)
                case .offLeadZoneLabel(let zone):
                    offLeadZoneLabelView(for: zone)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Planning Overlay

    @ViewBuilder
    var planningOverlay: some View {
        if isPlanningMode {
            PlanningModeOverlay(
                isActive: $isPlanningMode,
                waypoints: planningWaypoints,
                estimatedDistance: 0,
                estimatedDuration: 0,
                onAddWaypoint: { planningWaypoints.append($0) },
                onRemoveLastWaypoint: { if !planningWaypoints.isEmpty { planningWaypoints.removeLast() } },
                onSave: { },
                onStartWalk: { isPlanningMode = false; startWalk() },
                onCancel: { isPlanningMode = false; planningWaypoints.removeAll() }
            )
        }
    }
}

// MARK: - Location Manager

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?
    @Published var bearing: Double = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.location = location.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            bearing = newHeading.trueHeading
        }
    }
}

// MARK: - Torch Manager

class TorchManager {
    static let shared = TorchManager()

    func toggleTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch error: \(error)")
        }
    }
}

// MARK: - Walk Tracking ViewModel

@MainActor
class WalkTrackingViewModel: ObservableObject {
    @Published var isWalkActive = false
    @Published var walkDistance: Double = 0
    @Published var walkDuration: TimeInterval = 0

    private var walkStartTime: Date?
    private var timer: Timer?

    func startWalk() {
        isWalkActive = true
        walkStartTime = Date()
        walkDistance = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.walkStartTime else { return }
            self.walkDuration = Date().timeIntervalSince(startTime)
        }
    }

    func stopWalk() {
        isWalkActive = false
        timer?.invalidate()
        timer = nil
    }

    func updateLocation(_ location: CLLocationCoordinate2D) {
    }
}

// MARK: - Poo Bag Drop ViewModel

@MainActor
class PooBagDropViewModel: ObservableObject {
    @Published var activeBagDrops: [PooBagDrop] = []

    func markAsCollected(_ id: String) {
        activeBagDrops.removeAll { $0.id == id }
    }
}

#if false
// DISABLED: Duplicate RoutingViewModel stub - real version in ViewModels/RoutingViewModel.swift
class RoutingViewModel: ObservableObject {
    @Published var routePreview: RoutePreview?
    @Published var isCalculating = false

    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        isCalculating = true

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isCalculating = false

                if let route = response?.routes.first {
                    self?.routePreview = RoutePreview(
                        route: route,
                        destination: destination
                    )
                }
            }
        }
    }
}
#endif

#if false
// DISABLED: Duplicate RoutePreview stub - real version in ViewModels/RoutingViewModel.swift
struct RoutePreview {
    let route: MKRoute
    let destination: CLLocationCoordinate2D
}
#endif

// MARK: - Map Marker Item

struct MapMarkerItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind

    enum Kind {
        case poi(POI)
        case pooBag(PooBagDrop)
        case publicDog(PublicDog)
        case lostDog(LostDog)
        case car
        case hazard(HazardReport)
        case trailCondition(TrailCondition)
        case offLeadZoneLabel(OffLeadZone)
    }
}

// MARK: - CLLocationCoordinate2D Equatable

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
