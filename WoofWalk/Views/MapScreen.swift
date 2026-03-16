import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @StateObject private var mapViewModel = MapViewModel()
    @StateObject private var routingViewModel = RoutingViewModel()
    @StateObject private var guidanceViewModel = GuidanceViewModel()
    @StateObject private var walkTrackingViewModel = WalkTrackingViewModel()
    @StateObject private var pooBagDropViewModel = PooBagDropViewModel()
    @StateObject private var locationManager = LocationManager()

    @State private var showSearchBar = false
    @State private var showFilterSheet = false
    @State private var showPOIDetailSheet = false
    @State private var selectedPOI: POI?
    @State private var selectedBagDrop: PooBagDrop?
    @State private var selectedPublicDog: PublicDog?
    @State private var selectedLostDog: LostDog?
    @State private var showPublicDogSheet = false
    @State private var showLostDogSheet = false
    @State private var showMapClickDialog = false
    @State private var showDistancePickerDialog = false
    @State private var showPOISelectionDialog = false
    @State private var showCarOptionsDialog = false
    @State private var showAppGuide = false
    @State private var showWalkSummary = false
    @State private var clickedLocation: CLLocationCoordinate2D?
    @State private var isTorchOn = false
    @State private var carLocation: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showRoutePreview = false
    @State private var routePreview: RoutePreview?
    @State private var completedDistance: Double = 0
    @State private var completedDuration: Int = 0
    @State private var mapStyle: WoofWalkMapStyle = .standard
    @State private var isPlanningMode = false
    @State private var planningWaypoints: [CLLocationCoordinate2D] = []
    @State private var showBackgroundLocationPrompt = false
    @State private var showRouteStartProximity = false
    @State private var pendingRouteStart: CLLocationCoordinate2D?
    @AppStorage("hasShownBackgroundLocationPrompt") private var hasShownPrompt = false

    var body: some View {
        ZStack {
            MapView(
                viewModel: mapViewModel,
                locationManager: locationManager,
                cameraPosition: $cameraPosition,
                onMapTap: handleMapTap,
                onPOITap: handlePOITap,
                onBagDropTap: handleBagDropTap,
                onPublicDogTap: handlePublicDogTap,
                onLostDogTap: handleLostDogTap,
                carLocation: carLocation
            )
            .ignoresSafeArea()

            VStack {
                HStack(alignment: .top, spacing: 12) {
                    Button(action: { showAppGuide = true }) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(.blue.opacity(0.8)))
                    }

                    Spacer()

                    topRightControls
                }
                .padding()

                Spacer()

                if let guidanceState = guidanceViewModel.guidanceState,
                   case .active = guidanceState {
                    GuidancePanel(
                        guidanceState: guidanceState,
                        walkDistance: walkTrackingViewModel.walkDistance,
                        walkDuration: walkTrackingViewModel.walkDuration,
                        onDismiss: {
                            if walkTrackingViewModel.isWalkActive {
                                stopWalk()
                            }
                            guidanceViewModel.stopGuidance()
                        }
                    )
                    .padding(.horizontal)
                } else if walkTrackingViewModel.isWalkActive {
                    WalkControlPanel(
                        isWalking: true,
                        isPaused: false,
                        distance: walkTrackingViewModel.walkDistance,
                        duration: walkTrackingViewModel.walkDuration,
                        currentPace: 0,
                        averagePace: 0,
                        onPause: { },
                        onResume: { },
                        onStop: stopWalk,
                        onAddPhoto: { },
                        onMarkWaste: { quickAddPooBag() }
                    )
                    .padding(.horizontal)
                }

                Spacer()

                HStack(alignment: .bottom) {
                    VStack(spacing: 12) {
                        quickAddButton(
                            icon: "trash.fill",
                            color: .green,
                            action: quickAddBin
                        )

                        quickAddButton(
                            icon: "bag.fill",
                            color: .orange,
                            action: quickAddPooBag
                        )
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        if walkTrackingViewModel.isWalkActive {
                            Button(action: mapViewModel.cycleCameraMode) {
                                Image(systemName: mapViewModel.cameraModeIcon)
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Circle().fill(.blue))
                            }
                        }

                        Button(action: addPOI) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Circle().fill(.blue))
                        }

                        Button(action: { isPlanningMode.toggle() }) {
                            Image(systemName: isPlanningMode ? "pencil.circle.fill" : "pencil.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Circle().fill(isPlanningMode ? .orange : .blue.opacity(0.8)))
                        }

                        Button(action: toggleWalk) {
                            Image(systemName: walkTrackingViewModel.isWalkActive ? "stop.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Circle().fill(walkTrackingViewModel.isWalkActive ? .red : .green))
                        }
                    }
                }
                .padding()
            }

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
        .sheet(isPresented: $showSearchBar) {
            SearchBarView(viewModel: mapViewModel)
        }
        .sheet(isPresented: $showFilterSheet) {
            POIFilterSheet(viewModel: mapViewModel)
        }
        .sheet(isPresented: $showPOIDetailSheet) {
            if let poi = selectedPOI {
                POIDetailSheet(poi: poi, viewModel: mapViewModel)
            }
        }
        .sheet(isPresented: $showPublicDogSheet) {
            if let dog = selectedPublicDog {
                PublicDogInfoSheet(publicDog: dog)
            }
        }
        .sheet(isPresented: $showLostDogSheet) {
            if let dog = selectedLostDog {
                LostDogInfoSheet(
                    lostDog: dog,
                    userLocation: locationManager.location,
                    onContact: {
                        if let phone = dog.reporterPhone {
                            callPhoneNumber(phone)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showAppGuide) {
            AppGuideView()
        }
        .sheet(isPresented: $showBackgroundLocationPrompt) {
            BackgroundLocationPrompt(
                isPresented: $showBackgroundLocationPrompt,
                onEnable: {
                    locationManager.requestAlwaysAuthorization()
                    walkTrackingViewModel.startWalk()
                    mapViewModel.startWalkTracking()
                },
                onSkip: {
                    walkTrackingViewModel.startWalk()
                    mapViewModel.startWalkTracking()
                }
            )
        }
        .sheet(item: $selectedBagDrop) { bagDrop in
            PooBagBottomSheet(
                bagDrop: bagDrop,
                onCollected: {
                    pooBagDropViewModel.markAsCollected(bagDrop.id)
                    selectedBagDrop = nil
                },
                onWalkToBag: {
                    if let userLocation = locationManager.location {
                        routingViewModel.calculateRoute(
                            from: userLocation,
                            to: bagDrop.toLatLng()
                        )
                        selectedBagDrop = nil
                    }
                }
            )
        }
        .alert("What would you like to do?", isPresented: $showMapClickDialog) {
            Button("Walk Here") {
                if let location = clickedLocation {
                    pendingRouteStart = location
                    showRouteStartProximity = true
                }
            }
            Button("Create Random Walk") {
                showPOISelectionDialog = true
            }
            Button("Cancel", role: .cancel) {
                clickedLocation = nil
            }
        }
        .alert("Car Location", isPresented: $showCarOptionsDialog) {
            Button("Navigate to Car") {
                if let userLocation = locationManager.location,
                   let car = carLocation {
                    routingViewModel.calculateRoute(from: userLocation, to: car)
                }
            }
            Button("Clear Location", role: .destructive) {
                carLocation = nil
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showWalkSummary) {
            WalkCompletionScreen(
                distance: completedDistance,
                duration: completedDuration,
                pace: completedDistance > 0 ? (Double(completedDuration) / 60.0) / (completedDistance / 1000.0) : 0,
                steps: 0,
                dogNames: [],
                pointsEarned: WalkPointsCalculator.calculatePoints(
                    distanceKm: completedDistance / 1000.0,
                    durationSec: completedDuration,
                    streakDays: 0,
                    charityEnabled: false
                ).totalPoints,
                personalBest: nil,
                streakDays: 0,
                milestones: [],
                mapImage: nil,
                onShare: { showWalkSummary = false },
                onDone: { showWalkSummary = false }
            )
        }
        .sheet(isPresented: $showRouteStartProximity) {
            if let start = pendingRouteStart {
                RouteStartProximitySheet(
                    routeStartLocation: start,
                    userLocation: locationManager.location,
                    routeName: "Planned Walk",
                    onNavigateToStart: {
                        if let userLoc = locationManager.location {
                            routingViewModel.calculateRoute(from: userLoc, to: start)
                        }
                        showRouteStartProximity = false
                    },
                    onStartAnyway: {
                        showRouteStartProximity = false
                        startWalk()
                    },
                    onCancel: {
                        showRouteStartProximity = false
                        pendingRouteStart = nil
                    }
                )
            }
        }
        .onAppear {
            mapViewModel.loadPOIs()
            locationManager.startUpdatingLocation()
        }
        .onChange(of: locationManager.location) { newLocation in
            if let location = newLocation {
                mapViewModel.updateWalkPolyline(with: location)
                walkTrackingViewModel.updateLocation(location)
            }
        }
    }

    private var topRightControls: some View {
        HStack(spacing: 8) {
            Button(action: { showSearchBar = true }) {
                Image(systemName: "magnifyingglass")
                    .controlButtonStyle()
            }

            Button(action: { showFilterSheet = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .controlButtonStyle()
            }

            Button(action: centerOnUser) {
                Image(systemName: "location.fill")
                    .controlButtonStyle()
            }

            Button(action: toggleTorch) {
                Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title3)
                    .foregroundColor(isTorchOn ? .yellow : .primary)
                    .padding(8)
                    .background(Circle().fill(.regularMaterial))
            }

            Button(action: handleCarButton) {
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundColor(carLocation != nil ? .cyan : .primary)
                    .padding(8)
                    .background(Circle().fill(.regularMaterial))
            }

            MapStyleToggle(selectedStyle: $mapStyle)
        }
    }

    private func quickAddButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .padding(12)
                .background(Circle().fill(color))
        }
    }

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        guard !walkTrackingViewModel.isWalkActive else { return }
        clickedLocation = coordinate
        showMapClickDialog = true
    }

    private func handlePOITap(_ poi: POI) {
        selectedPOI = poi
        showPOIDetailSheet = true
    }

    private func handleBagDropTap(_ bagDrop: PooBagDrop) {
        selectedBagDrop = bagDrop
    }

    private func handlePublicDogTap(_ dog: PublicDog) {
        selectedPublicDog = dog
        showPublicDogSheet = true
    }

    private func handleLostDogTap(_ dog: LostDog) {
        selectedLostDog = dog
        showLostDogSheet = true
    }

    private func toggleWalk() {
        if walkTrackingViewModel.isWalkActive {
            stopWalk()
        } else {
            startWalk()
        }
    }

    private func startWalk() {
        guard guidanceViewModel.guidanceState == nil else {
            return
        }
        if !hasShownPrompt {
            showBackgroundLocationPrompt = true
            hasShownPrompt = true
            return
        }
        walkTrackingViewModel.startWalk()
        mapViewModel.startWalkTracking()
    }

    private func stopWalk() {
        completedDistance = walkTrackingViewModel.walkDistance
        completedDuration = Int(walkTrackingViewModel.walkDuration)
        walkTrackingViewModel.stopWalk()
        mapViewModel.stopWalkTracking()
        showWalkSummary = true

        Task {
            await BadgeAwardingService.shared.checkAndAwardBadges(
                walkDistance: completedDistance,
                totalWalks: 0,
                totalDistance: completedDistance,
                poisCreated: 0,
                votesGiven: 0
            )
        }
    }

    private func addPOI() {
        guard let location = locationManager.location else { return }
        mapViewModel.addPOI(type: .bin, at: location)
    }

    private func quickAddBin() {
        guard let location = locationManager.location else { return }
        mapViewModel.addPOI(type: .bin, at: location)
    }

    private func quickAddPooBag() {
        guard let location = locationManager.location else { return }
        mapViewModel.addPooBagDrop(at: location)
    }

    private func centerOnUser() {
        if let location = locationManager.location {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: location,
                    distance: 1000
                )
            )
        }
    }

    private func toggleTorch() {
        isTorchOn.toggle()
        TorchManager.shared.toggleTorch(isTorchOn)
    }

    private func handleCarButton() {
        if carLocation == nil {
            if let location = locationManager.location {
                carLocation = location
            }
        } else {
            showCarOptionsDialog = true
        }
    }

    private func callPhoneNumber(_ phone: String) {
        if let url = URL(string: "tel://\(phone)") {
            UIApplication.shared.open(url)
        }
    }
}

extension View {
    func controlButtonStyle() -> some View {
        self
            .font(.title3)
            .foregroundColor(.primary)
            .padding(8)
            .background(Circle().fill(.regularMaterial))
    }
}

struct PooBagBottomSheet: View {
    let bagDrop: PooBagDrop
    let onCollected: () -> Void
    let onWalkToBag: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Poo Bag Drop")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Dropped \(bagDrop.getAgeMinutes()) minutes ago")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let notes = bagDrop.notes {
                    Text(notes)
                        .font(.body)
                }

                Button(action: onWalkToBag) {
                    HStack {
                        Image(systemName: "figure.walk")
                        Text("Walk to Bag")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: onCollected) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Collected")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PublicDogInfoSheet: View {
    let publicDog: PublicDog

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        if let photoUrl = publicDog.dogPhotoUrl,
                           let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                        }

                        VStack(alignment: .leading) {
                            Text(publicDog.dogName)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(publicDog.dogBreed)
                                .font(.body)
                            Text("Owner: \(publicDog.ownerName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if publicDog.nervousDog {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text("Nervous/Reactive Dog")
                                    .fontWeight(.bold)
                                if let warning = publicDog.warningNote {
                                    Text(warning)
                                        .font(.caption)
                                } else {
                                    Text("Please give space")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Dog Info")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LostDogInfoSheet: View {
    let lostDog: LostDog
    let userLocation: CLLocationCoordinate2D?
    let onContact: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        if let photoUrl = lostDog.dogPhotoUrl,
                           let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                        }

                        VStack(alignment: .leading) {
                            Text("LOST: \(lostDog.dogName)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            Text(lostDog.dogBreed)
                                .font(.body)
                            Text("Reporter: \(lostDog.reporterName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !lostDog.locationDescription.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Last Seen")
                                .font(.headline)
                            Text(lostDog.locationDescription)
                        }
                    }

                    if !lostDog.description.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Description")
                                .font(.headline)
                            Text(lostDog.description)
                        }
                    }

                    if lostDog.reporterPhone != nil {
                        Button(action: onContact) {
                            HStack {
                                Image(systemName: "phone.fill")
                                Text("Contact Reporter")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Lost Dog")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        bearing = newHeading.trueHeading
    }
}

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

class PooBagDropViewModel: ObservableObject {
    @Published var activeBagDrops: [PooBagDrop] = []

    func markAsCollected(_ id: String) {
        activeBagDrops.removeAll { $0.id == id }
    }
}

struct RoutePreview {
    let route: MKRoute
    let destination: CLLocationCoordinate2D
}

import AVFoundation
