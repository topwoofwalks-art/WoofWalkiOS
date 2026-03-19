import SwiftUI
import MapKit
import CoreLocation
import AVFoundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

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
    @State var carLocation: CLLocationCoordinate2D? = {
        let lat = UserDefaults.standard.double(forKey: "carLocationLat")
        let lng = UserDefaults.standard.double(forKey: "carLocationLng")
        guard lat != 0 || lng != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }()
    @State var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    @State var showRoutePreview = false
    @State var routePreview: RoutePreview?
    @State var completedDistance: Double = 0
    @State var completedDuration: Int = 0
    @StateObject var settingsViewModel = SettingsViewModel()
    @ObservedObject var buttonTestCoordinator = ButtonTestCoordinator.shared
    @StateObject var walkPathVM = WalkPathVM()
    @StateObject var livestockFieldVM = LivestockFieldViewModel()
    @State var mapStyle: WoofWalkMapStyle = .standard
    @State var isPlanningMode = false
    @State var showSavePlannedWalkDialog = false
    @State var showBackgroundLocationPrompt = false
    @State var showRouteStartProximity = false
    @State var pendingRouteStart: CLLocationCoordinate2D?
    @State var showLivestockMode = false
    @State var showWalkingPaths = false
    @State var dismissedHazardIds: Set<String> = []
    @State var showRainMode = false
    @State var showFogOfWar = false
    @State var fogOfWarCoordinates: [CLLocationCoordinate2D] = []
    @State var showTrailConditionSheet = false
    @State var showNearbyPubsSheet = false
    @State var showPubDetailSheet = false
    @State var selectedPub: POI?
    @State var showClusterSelectionSheet = false
    @State var selectedCluster: AnnotationCluster?
    @State var pendingPlannedWalk: PlannedWalk?
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
            FogOfWarOverlay(
                exploredCoordinates: fogOfWarCoordinates,
                isEnabled: $showFogOfWar
            )
            // Rain mode indicator overlay (visual only when active)
            if showRainMode {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "cloud.rain.fill")
                            .font(.caption)
                        Text("Rain Mode")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.blue.opacity(0.85)))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                    Spacer()
                }
            }
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
                    let userId = Auth.auth().currentUser?.uid ?? "anonymous"
                    let condition = TrailCondition(
                        type: type.rawValue,
                        severity: severity,
                        note: note,
                        lat: location.latitude,
                        lng: location.longitude,
                        reportedBy: userId,
                        voteUp: 0,
                        voteDown: 0
                    )
                    mapViewModel.trailConditions.append(condition)
                    // Save to Firestore
                    let db = Firestore.firestore()
                    let data: [String: Any] = [
                        "type": type.rawValue, "severity": severity,
                        "note": note, "lat": location.latitude, "lng": location.longitude,
                        "reportedBy": userId, "reportedAt": Timestamp(date: Date()),
                        "voteUp": 0, "voteDown": 0
                    ]
                    db.collection("trailConditions").addDocument(data: data) { error in
                        if let error = error {
                            print("[MapScreen] Failed to save trail condition: \(error.localizedDescription)")
                        }
                    }
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
        .sheet(isPresented: $showSavePlannedWalkDialog) {
            SavePlannedWalkDialog(
                isPresented: $showSavePlannedWalkDialog,
                waypoints: mapViewModel.planningWaypoints,
                distance: mapViewModel.plannedRouteDistance,
                duration: mapViewModel.plannedRouteDuration,
                onSave: { title, description, date in
                    let repo = PlannedWalkRepository()
                    let distance = mapViewModel.plannedRouteDistance
                    let duration = mapViewModel.plannedRouteDuration

                    // Use the combined detailed polyline (from OSRM routing) if available,
                    // otherwise fall back to raw waypoints
                    let detailedPolyline = mapViewModel.combinedPlanningPolyline
                    let polylineToSave = detailedPolyline.count > mapViewModel.planningWaypoints.count
                        ? detailedPolyline
                        : mapViewModel.planningWaypoints

                    let startLocation = polylineToSave.first.map {
                        LatLngData(latitude: $0.latitude, longitude: $0.longitude)
                    } ?? LatLngData()

                    let walk = PlannedWalk(
                        id: UUID().uuidString,
                        userId: "",
                        title: title,
                        description: description,
                        startLocation: startLocation,
                        startLocationName: "",
                        routePolyline: polylineToSave.map { LatLngData(latitude: $0.latitude, longitude: $0.longitude) },
                        estimatedDistanceMeters: distance,
                        estimatedDurationSec: Int64(duration),
                        plannedForDate: date.map { Int64($0.timeIntervalSince1970 * 1000) },
                        notes: [],
                        dogIds: [],
                        poiIds: [],
                        createdAt: Int64(Date().timeIntervalSince1970 * 1000),
                        updatedAt: Int64(Date().timeIntervalSince1970 * 1000)
                    )

                    Task {
                        do {
                            let _ = try await repo.savePlannedWalk(walk)
                            await MainActor.run {
                                isPlanningMode = false
                                mapViewModel.clearAllPlanningWaypoints()
                            }
                        } catch {
                            print("Error saving planned walk: \(error.localizedDescription)")
                        }
                    }
                }
            )
        }
        .onAppear {
            locationManager.startUpdatingLocation()
            mapViewModel.loadPOIs(near: locationManager.location)
            // Only load Firestore data if Firebase is configured
            if FirebaseApp.app() != nil {
                mapViewModel.loadHazardReports()
                mapViewModel.loadTrailConditions()
                mapViewModel.loadPublicDogs()
                mapViewModel.loadLostDogs()
            }
            // Sync map style from settings
            switch settingsViewModel.settings.mapStyle {
            case .standard: mapStyle = .standard
            case .hybrid: mapStyle = .hybrid
            case .satellite: mapStyle = .satellite
            }
        }
        .onChange(of: locationManager.location) { newLocation in
            if let location = newLocation {
                mapViewModel.updateWalkPolyline(with: location)
                walkTrackingViewModel.updateLocation(location)
                // Feed location to guidance for turn-by-turn tracking
                if case .active = guidanceViewModel.guidanceState {
                    guidanceViewModel.updateUserLocation(location)
                }
                if showFogOfWar && walkTrackingViewModel.isWalkActive {
                    fogOfWarCoordinates.append(location)
                }
            }
        }
        .onReceive(AppNavigator.shared.$pendingPlannedWalk) { walk in
            guard let walk = walk else { return }
            AppNavigator.shared.pendingPlannedWalk = nil
            executePlannedWalk(walk)
        }
        .onChange(of: buttonTestCoordinator.currentCommand) { command in
            handleTestCommand(command)
        }
    }

    // MARK: - Button Test Command Handler

    private func handleTestCommand(_ command: TestCommand) {
        let coord = ButtonTestCoordinator.shared
        guard command != .none else { return }

        switch command {
        case .tapCarButton:
            handleCarButton()
            coord.reportResult("Car button tapped, carLocation=\(carLocation != nil)")
        case .tapFilterButton, .openFilterSheet:
            showFilterSheet = true
            coord.reportResult("Filter sheet opened")
        case .closeFilterSheet, .closeSheet:
            showFilterSheet = false
            showNearbyPubsSheet = false
            showTrailConditionSheet = false
            coord.reportResult("Sheets closed")
        case .tapLocationButton:
            centerOnUser()
            coord.reportResult("Centered on user location")
        case .tapTorchButton:
            toggleTorch()
            coord.reportResult("Torch toggled, isTorchOn=\(isTorchOn)")
        case .tapLivestockButton:
            showLivestockMode.toggle()
            coord.reportResult("Livestock mode=\(showLivestockMode)")
        case .tapWalkingPathsButton:
            showWalkingPaths.toggle()
            coord.reportResult("Walking paths=\(showWalkingPaths)")
        case .tapRainModeButton, .enableRainMode:
            showRainMode = true
            coord.reportResult("Rain mode enabled")
        case .disableRainMode:
            showRainMode = false
            coord.reportResult("Rain mode disabled")
        case .tapPubsButton, .openNearbyPubsSheet:
            showNearbyPubsSheet = true
            coord.reportResult("Nearby pubs sheet opened")
        case .tapAddPOIButton:
            addPOI()
            coord.reportResult("Add POI triggered")
        case .tapWalkButton:
            toggleWalk()
            coord.reportResult("Walk toggled, isActive=\(walkTrackingViewModel.isWalkActive)")
        case .startWalk:
            if !walkTrackingViewModel.isWalkActive { startWalk() }
            coord.reportResult("Walk started")
        case .stopWalk:
            if walkTrackingViewModel.isWalkActive { stopWalk() }
            coord.reportResult("Walk stopped")
        case .tapQuickAddBin:
            quickAddBin()
            coord.reportResult("Quick add bin triggered")
        case .verifyMapLoaded:
            let hasPois = !mapViewModel.pois.isEmpty
            coord.reportResult("Map loaded, POIs=\(mapViewModel.pois.count), hasPois=\(hasPois)")
        case .verifyPOIsVisible:
            let filtered = mapViewModel.filteredPOIs.count
            coord.reportResult("Filtered POIs visible: \(filtered)")
        case .verifyBinDistanceVisible:
            let bins = mapViewModel.pois.filter { $0.poiType == .bin }
            coord.reportResult("Bins loaded: \(bins.count)")
        // L2 data flow verification
        case .verifyPOICount:
            coord.reportResult("Total POIs: \(mapViewModel.pois.count), filtered: \(mapViewModel.filteredPOIs.count)")
        case .verifyBinCount:
            let bins = mapViewModel.pois.filter { $0.poiType == .bin }
            coord.reportResult("Bins: \(bins.count)")
        case .verifyPubCount:
            let pubs = mapViewModel.pois.filter { $0.poiType == .dogFriendlyPub }
            coord.reportResult("Pubs: \(pubs.count)")
        case .verifyMapViewModelState:
            let state = "pois=\(mapViewModel.pois.count) hazards=\(mapViewModel.hazardReports.count) trails=\(mapViewModel.trailConditions.count) dogs=\(mapViewModel.publicDogs.count) lost=\(mapViewModel.lostDogs.count)"
            coord.reportResult("MapVM: \(state)")
        case .verifyWalkTrackingState:
            coord.reportResult("Walk: active=\(walkTrackingViewModel.isWalkActive) dist=\(walkTrackingViewModel.walkDistance) dur=\(walkTrackingViewModel.walkDuration)")
        // L3 sheet content
        case .openFilterSheetAndVerify:
            showFilterSheet = true
            let typeCount = POI.POIType.allCases.count
            coord.reportResult("Filter sheet opened, \(typeCount) POI types available")
        case .openPubsSheetAndVerify:
            showNearbyPubsSheet = true
            let pubs = mapViewModel.pois.filter { $0.poiType == .dogFriendlyPub }
            coord.reportResult("Pubs sheet opened, \(pubs.count) pubs available")
        case .openTrailConditionSheet:
            showTrailConditionSheet = true
            coord.reportResult("Trail condition sheet opened")
        case .closeTrailConditionSheet:
            showTrailConditionSheet = false
            coord.reportResult("Trail condition sheet closed")
        // L4 form submission
        case .submitQuickBin:
            quickAddBin()
            coord.reportResult("Quick bin submitted at current location")
        case .verifyBinAdded:
            let bins = mapViewModel.pois.filter { $0.poiType == .bin }
            coord.reportResult("Bin count after add: \(bins.count)")
        // L5 walk lifecycle
        case .verifyWalkActive:
            coord.reportResult("Walk active: \(walkTrackingViewModel.isWalkActive)")
        case .verifyWalkDistance:
            coord.reportResult("Walk distance: \(walkTrackingViewModel.walkDistance)m, duration: \(walkTrackingViewModel.walkDuration)s")
        case .verifyWalkStopped:
            coord.reportResult("Walk stopped: active=\(walkTrackingViewModel.isWalkActive) finalDist=\(walkTrackingViewModel.walkDistance)")
        // L8 error resilience
        case .addPOIWithNoLocation:
            // Should not crash when location is nil
            mapViewModel.addPOI(type: .bin, at: CLLocationCoordinate2D(latitude: 0, longitude: 0))
            coord.reportResult("POI added at 0,0 without crash")
        case .startWalkWithNoLocation:
            if !walkTrackingViewModel.isWalkActive {
                walkTrackingViewModel.startWalk()
                walkTrackingViewModel.stopWalk()
            }
            coord.reportResult("Walk start/stop with no GPS - no crash")
        case .toggleAllFiltersOff:
            mapViewModel.selectedPOITypes = []
            let filtered = mapViewModel.filteredPOIs.count
            coord.reportResult("All filters off, visible: \(filtered)")
        case .toggleAllFiltersOn:
            mapViewModel.selectedPOITypes = Set(POI.POIType.allCases)
            let filtered = mapViewModel.filteredPOIs.count
            coord.reportResult("All filters on, visible: \(filtered)")
        case .rapidToggleRainMode:
            for _ in 0..<10 { showRainMode.toggle() }
            showRainMode = false
            coord.reportResult("Rain mode toggled 10x rapidly, final=off")
        case .rapidToggleTorch:
            for _ in 0..<6 {
                isTorchOn.toggle()
            }
            isTorchOn = false
            coord.reportResult("Torch toggled 6x rapidly, final=off")
        // L9 state persistence
        case .saveCarLocation:
            carLocation = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
            UserDefaults.standard.set(51.5, forKey: "carLocationLat")
            UserDefaults.standard.set(-0.1, forKey: "carLocationLng")
            coord.reportResult("Car location saved to 51.5,-0.1")
        case .verifyCarLocationSaved:
            let lat = UserDefaults.standard.double(forKey: "carLocationLat")
            let lng = UserDefaults.standard.double(forKey: "carLocationLng")
            let hasLoc = carLocation != nil
            coord.reportResult("Car persisted: lat=\(lat) lng=\(lng) stateHasLoc=\(hasLoc)")
        case .clearCarLocationPersisted:
            clearCarLocation()
            coord.reportResult("Car location cleared")
        case .verifyCarLocationCleared:
            let lat = UserDefaults.standard.double(forKey: "carLocationLat")
            let hasLoc = carLocation != nil
            coord.reportResult("Car cleared: lat=\(lat) stateHasLoc=\(hasLoc)")
        case .verifySettingsLoaded:
            let style = settingsViewModel.settings.mapStyle.rawValue
            let rain = settingsViewModel.settings.rainAutoDetection
            coord.reportResult("Settings: mapStyle=\(style) rainAutoDetect=\(rain)")
        // L10 performance
        case .rapidTabSwitch:
            for tab in AppTab.allCases {
                AppNavigator.shared.selectedTab = tab
            }
            AppNavigator.shared.selectedTab = .map
            coord.reportResult("Cycled all 5 tabs rapidly, no crash")
        case .rapidRouteNavigation:
            for route in [AppRoute.settings, .challenges, .league, .badgeGallery, .milestones] {
                AppNavigator.shared.navigate(to: route)
                AppNavigator.shared.popToRoot()
            }
            coord.reportResult("Navigated 5 routes rapidly with popToRoot, no crash")
        case .stressTestFilterToggle:
            for type in POI.POIType.allCases {
                mapViewModel.togglePOIType(type)
            }
            for type in POI.POIType.allCases {
                mapViewModel.togglePOIType(type)
            }
            coord.reportResult("Toggled all \(POI.POIType.allCases.count) filters twice, no crash")
        // L11 boundary values
        case .addPOIAtMaxCoords:
            mapViewModel.addPOI(type: .bin, at: CLLocationCoordinate2D(latitude: 90.0, longitude: 180.0))
            coord.reportResult("POI at max coords (90,180) - no crash")
        case .addPOIAtMinCoords:
            mapViewModel.addPOI(type: .bin, at: CLLocationCoordinate2D(latitude: -90.0, longitude: -180.0))
            coord.reportResult("POI at min coords (-90,-180) - no crash")
        case .addPOIAtAntimeridian:
            mapViewModel.addPOI(type: .bin, at: CLLocationCoordinate2D(latitude: 0.0, longitude: 179.9999))
            coord.reportResult("POI at antimeridian - no crash")
        case .walkWithZeroDistance:
            walkTrackingViewModel.startWalk()
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Zero-distance walk start/stop - no crash, dist=\(walkTrackingViewModel.walkDistance)")
        case .filterWithEmptyPOIs:
            let saved = mapViewModel.pois
            mapViewModel.pois = []
            let count = mapViewModel.filteredPOIs.count
            mapViewModel.pois = saved
            coord.reportResult("Filter with empty POIs: \(count), restored \(saved.count)")
        case .verifyAfterChaos:
            let pois = mapViewModel.pois.count
            let filtered = mapViewModel.filteredPOIs.count
            let active = walkTrackingViewModel.isWalkActive
            coord.reportResult("After chaos: pois=\(pois) filtered=\(filtered) walkActive=\(active) rainMode=\(showRainMode)")
        // L12 memory pressure
        case .loadPOIsTwice:
            mapViewModel.loadPOIs(near: region.center)
            mapViewModel.loadPOIs(near: region.center)
            coord.reportResult("Double POI load triggered - no crash")
        case .toggleAllButtonsRapidly:
            showRainMode.toggle(); showRainMode.toggle()
            showLivestockMode.toggle(); showLivestockMode.toggle()
            showWalkingPaths.toggle(); showWalkingPaths.toggle()
            isTorchOn.toggle(); isTorchOn.toggle()
            showFogOfWar.toggle(); showFogOfWar.toggle()
            coord.reportResult("All buttons toggled on/off rapidly - no crash")
        case .openCloseAllSheets:
            showFilterSheet = true; showFilterSheet = false
            showNearbyPubsSheet = true; showNearbyPubsSheet = false
            showTrailConditionSheet = true; showTrailConditionSheet = false
            showMapClickDialog = true; showMapClickDialog = false
            showPOISelectionDialog = true; showPOISelectionDialog = false
            coord.reportResult("All 5 sheets opened/closed rapidly - no crash")
        case .navigateAllRoutesFast:
            let routes: [AppRoute] = [.settings, .challenges, .league, .badgeGallery, .milestones,
                .hazardReport, .offLeadZones, .rainModeSettings, .plannedWalks, .routeLibrary,
                .nearbyPubs, .languageSettings, .notificationSettings, .privacySettings,
                .notifications, .charitySettings, .chatList, .discovery, .walkHistory, .stats]
            for route in routes {
                AppNavigator.shared.navigate(to: route)
                AppNavigator.shared.popToRoot()
            }
            coord.reportResult("Navigated \(routes.count) routes with instant popToRoot - no crash")
        // L13 state corruption
        case .walkDuringModeSwitch:
            walkTrackingViewModel.startWalk()
            AppNavigator.shared.switchMode(.business)
            AppNavigator.shared.switchMode(.public_)
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Walk during mode switch - no crash, walk stopped cleanly")
        case .modeWhileSheetOpen:
            showFilterSheet = true
            AppNavigator.shared.switchMode(.business)
            AppNavigator.shared.switchMode(.public_)
            showFilterSheet = false
            coord.reportResult("Mode switch while sheet open - no crash")
        case .doubleStartWalk:
            walkTrackingViewModel.startWalk()
            walkTrackingViewModel.startWalk()
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Double start walk - no crash")
        case .doubleStopWalk:
            walkTrackingViewModel.stopWalk()
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Double stop walk - no crash")
        case .popEmptyNavigation:
            AppNavigator.shared.popToRoot()
            AppNavigator.shared.pop()
            AppNavigator.shared.pop()
            AppNavigator.shared.popToRoot()
            coord.reportResult("Pop empty nav stack 4x - no crash")
        case .navigateWhileWalking:
            walkTrackingViewModel.startWalk()
            AppNavigator.shared.navigate(to: .settings)
            AppNavigator.shared.popToRoot()
            AppNavigator.shared.navigate(to: .challenges)
            AppNavigator.shared.popToRoot()
            walkTrackingViewModel.stopWalk()
            coord.reportResult("Navigate settings+challenges during walk - no crash")
        case .none:
            break
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

        // Planning waypoints
        if isPlanningMode {
            let waypoints = mapViewModel.planningWaypoints
            for (index, wp) in waypoints.enumerated() {
                items.append(MapMarkerItem(
                    id: "planning-wp-\(index)",
                    coordinate: wp,
                    kind: .planningWaypoint(
                        index: index,
                        isFirst: index == 0,
                        isLast: index == waypoints.count - 1
                    )
                ))
            }
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
                    let hType = HazardType(rawValue: hazard.type)
                    ZStack {
                        Circle()
                            .fill((HazardSeverity(rawValue: hazard.severity) ?? .medium).color)
                            .frame(width: 40, height: 40)
                            .shadow(radius: 3)
                        Text(hType?.emoji ?? "⚠️")
                            .font(.system(size: 20))
                    }
                case .trailCondition(let condition):
                    let tType = TrailConditionType(rawValue: condition.type)
                    ZStack {
                        Circle()
                            .fill(tType?.color ?? .gray)
                            .frame(width: 36, height: 36)
                            .shadow(radius: 2)
                        Text(tType?.emoji ?? "❓")
                            .font(.system(size: 16))
                    }
                case .offLeadZoneLabel(let zone):
                    let zType = ZoneType(rawValue: zone.type)
                    Text(zType?.displayName ?? zone.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.regularMaterial))
                        .foregroundColor(zType?.color ?? .gray)
                case .planningWaypoint(let index, let isFirst, let isLast):
                    ZStack {
                        Circle()
                            .fill(isFirst ? Color.green : (isLast ? Color.orange : Color.turquoise60))
                            .frame(width: 28, height: 28)
                            .shadow(radius: 3)
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Planning Overlay

    @ViewBuilder
    var planningOverlay: some View {
        if isPlanningMode {
            PlanningModeOverlay(
                isActive: $isPlanningMode,
                waypoints: mapViewModel.planningWaypoints,
                estimatedDistance: mapViewModel.plannedRouteDistance,
                estimatedDuration: mapViewModel.plannedRouteDuration,
                isLoopClosed: mapViewModel.isLoopClosed,
                canCloseLoop: mapViewModel.planningWaypoints.count >= 3 && !mapViewModel.isLoopClosed,
                closingSegmentPreview: mapViewModel.closingSegmentPreview,
                mapCenterCoordinate: region.center,
                isFetchingRoute: mapViewModel.isFetchingRoute,
                useFootpathRouting: $mapViewModel.useFootpathRouting,
                onAddWaypoint: { mapViewModel.addPlanningWaypoint($0) },
                onRemoveLastWaypoint: { mapViewModel.removeLastPlanningWaypoint() },
                onClearAll: { mapViewModel.clearAllPlanningWaypoints() },
                onCloseLoop: { mapViewModel.closeLoop() },
                onSave: { showSavePlannedWalkDialog = true },
                onStartWalk: { isPlanningMode = false; startWalk() },
                onCancel: { isPlanningMode = false; mapViewModel.clearAllPlanningWaypoints() }
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

    private var lastLocation: CLLocationCoordinate2D?

    func updateLocation(_ location: CLLocationCoordinate2D) {
        guard isWalkActive else { return }
        if let last = lastLocation {
            let distance = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
            if distance > 1 && distance < 100 { // filter GPS jitter
                walkDistance += distance
            }
        }
        lastLocation = location
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
        case planningWaypoint(index: Int, isFirst: Bool, isLast: Bool)
    }
}

// MARK: - CLLocationCoordinate2D Equatable

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
