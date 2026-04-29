import SwiftUI
import MapKit
import CoreLocation

// MARK: - Sheet Modifiers

struct MapSheetModifiers: ViewModifier {
    @Binding var showSearchBar: Bool
    @Binding var showFilterSheet: Bool
    @Binding var showPOIDetailSheet: Bool
    @Binding var showPublicDogSheet: Bool
    @Binding var showLostDogSheet: Bool
    @Binding var showAppGuide: Bool
    @Binding var showBackgroundLocationPrompt: Bool
    @Binding var selectedBagDrop: PooBagDrop?
    @Binding var showRouteStartProximity: Bool

    let selectedPOI: POI?
    let selectedPublicDog: PublicDog?
    let selectedLostDog: LostDogAnnotation?
    let pendingRouteStart: CLLocationCoordinate2D?

    var mapViewModel: MapViewModel
    var locationManager: LocationManager
    var walkTrackingViewModel: WalkTrackingViewModel
    var routingViewModel: RoutingViewModel
    var pooBagDropViewModel: PooBagDropViewModel

    let callPhoneNumber: (String) -> Void
    let startWalk: () -> Void
    let onRouteStartProximityDismiss: () -> Void
    let onRouteStartNavigate: (CLLocationCoordinate2D) -> Void
    let onRouteStartAnyway: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(MapSheetModifiersGroup1(
                showSearchBar: $showSearchBar,
                showFilterSheet: $showFilterSheet,
                showPOIDetailSheet: $showPOIDetailSheet,
                showPublicDogSheet: $showPublicDogSheet,
                selectedPOI: selectedPOI,
                selectedPublicDog: selectedPublicDog,
                mapViewModel: mapViewModel
            ))
            .modifier(MapSheetModifiersGroup2(
                showLostDogSheet: $showLostDogSheet,
                showAppGuide: $showAppGuide,
                showBackgroundLocationPrompt: $showBackgroundLocationPrompt,
                selectedBagDrop: $selectedBagDrop,
                selectedLostDog: selectedLostDog,
                locationManager: locationManager,
                walkTrackingViewModel: walkTrackingViewModel,
                routingViewModel: routingViewModel,
                pooBagDropViewModel: pooBagDropViewModel,
                mapViewModel: mapViewModel,
                callPhoneNumber: callPhoneNumber
            ))
            .modifier(MapSheetModifiersGroup3(
                showRouteStartProximity: $showRouteStartProximity,
                pendingRouteStart: pendingRouteStart,
                locationManager: locationManager,
                onDismiss: onRouteStartProximityDismiss,
                onNavigate: onRouteStartNavigate,
                onStartAnyway: onRouteStartAnyway
            ))
    }
}

// MARK: - Sheet Modifiers Group 1

struct MapSheetModifiersGroup1: ViewModifier {
    @Binding var showSearchBar: Bool
    @Binding var showFilterSheet: Bool
    @Binding var showPOIDetailSheet: Bool
    @Binding var showPublicDogSheet: Bool

    let selectedPOI: POI?
    let selectedPublicDog: PublicDog?
    var mapViewModel: MapViewModel

    func body(content: Content) -> some View {
        content
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
    }
}

// MARK: - Sheet Modifiers Group 2

struct MapSheetModifiersGroup2: ViewModifier {
    @Binding var showLostDogSheet: Bool
    @Binding var showAppGuide: Bool
    @Binding var showBackgroundLocationPrompt: Bool
    @Binding var selectedBagDrop: PooBagDrop?

    let selectedLostDog: LostDogAnnotation?
    var locationManager: LocationManager
    var walkTrackingViewModel: WalkTrackingViewModel
    var routingViewModel: RoutingViewModel
    var pooBagDropViewModel: PooBagDropViewModel
    var mapViewModel: MapViewModel
    let callPhoneNumber: (String) -> Void

    func body(content: Content) -> some View {
        content
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
                        // WhenInUse + UIBackgroundModes "location" + allowsBackgroundLocationUpdates=true
                        // is sufficient for active-walk tracking. Always is only required for
                        // geofence monitoring while the app is backgrounded, which is opt-in
                        // via a separate prompt (see GeofenceManager).
                        locationManager.requestWhenInUseAuthorization()
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
                            routingViewModel.generateCircularRoute(
                                userLocation: userLocation,
                                viaPoint: bagDrop.coordinate
                            )
                            selectedBagDrop = nil
                        }
                    }
                )
            }
    }
}

// MARK: - Sheet Modifiers Group 3

struct MapSheetModifiersGroup3: ViewModifier {
    @Binding var showRouteStartProximity: Bool

    let pendingRouteStart: CLLocationCoordinate2D?
    var locationManager: LocationManager
    let onDismiss: () -> Void
    let onNavigate: (CLLocationCoordinate2D) -> Void
    let onStartAnyway: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showRouteStartProximity) {
                if let start = pendingRouteStart {
                    RouteStartProximitySheet(
                        routeStartLocation: start,
                        userLocation: locationManager.location,
                        routeName: "Planned Walk",
                        onNavigateToStart: { onNavigate(start) },
                        onStartAnyway: onStartAnyway,
                        onCancel: onDismiss
                    )
                }
            }
    }
}

// MARK: - Alert Modifiers

struct MapAlertModifiers: ViewModifier {
    @Binding var showMapClickDialog: Bool
    @Binding var showCarOptionsDialog: Bool
    @Binding var showPOISelectionDialog: Bool

    let clickedLocation: CLLocationCoordinate2D?
    let carLocation: CLLocationCoordinate2D?
    var locationManager: LocationManager
    var routingViewModel: RoutingViewModel
    let onWalkHere: (CLLocationCoordinate2D) -> Void
    let onClearClickedLocation: () -> Void
    let onClearCarLocation: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("What would you like to do?", isPresented: $showMapClickDialog) {
                Button("Walk Here") {
                    if let location = clickedLocation {
                        onWalkHere(location)
                    }
                }
                Button("Create Random Walk") {
                    showPOISelectionDialog = true
                }
                Button("Cancel", role: .cancel) {
                    onClearClickedLocation()
                }
            }
            .alert("Car Location", isPresented: $showCarOptionsDialog) {
                Button("Navigate to Car") {
                    if let userLocation = locationManager.location,
                       let car = carLocation {
                        routingViewModel.generateCircularRoute(userLocation: userLocation, viaPoint: car)
                    }
                }
                Button("Clear Location", role: .destructive) {
                    onClearCarLocation()
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

// MARK: - Full Screen Modifiers

struct MapFullScreenModifiers: ViewModifier {
    @Binding var showWalkSummary: Bool
    @ObservedObject var badgeService: BadgeAwardingService = .shared

    let completedDistance: Double
    let completedDuration: Int

    private var earnedPoints: Int {
        WalkPointsCalculator.calculatePoints(
            distanceMeters: completedDistance,
            durationSec: completedDuration,
            trackPoints: [],
            walksCompletedToday: 0,
            hasWalkedYesterday: false
        ).points
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showWalkSummary) {
                WalkCompletionScreen(
                    distance: completedDistance,
                    duration: completedDuration,
                    pace: completedDistance > 0 ? (Double(completedDuration) / 60.0) / (completedDistance / 1000.0) : 0,
                    steps: 0,
                    dogNames: [],
                    pointsEarned: earnedPoints,
                    personalBest: nil,
                    streakDays: 0,
                    milestones: [],
                    achievements: badgeService.pendingAchievements,
                    mapImage: nil,
                    onShare: { showWalkSummary = false },
                    onDone: { showWalkSummary = false }
                )
                .task {
                    // Update weekly league score after walk completion
                    let points = earnedPoints
                    guard points > 0 else { return }
                    do {
                        try await LeagueRepository().addWeeklyPoints(points)
                    } catch {
                        print("Failed to update league points (non-fatal): \(error)")
                    }
                }
            }
    }
}

// MARK: - Poo Bag Bottom Sheet

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

                Text("Dropped \(bagDrop.ageMinutes()) minutes ago")
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

// MARK: - Public Dog Info Sheet

struct PublicDogInfoSheet: View {
    let publicDog: PublicDog

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        if let url = publicDog.photoURL {
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
                            Text(publicDog.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(publicDog.breed)
                                .font(.body)
                            Text("Owner: \(publicDog.ownerName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if publicDog.isNervous {
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

// MARK: - Lost Dog Info Sheet

struct LostDogInfoSheet: View {
    let lostDog: LostDogAnnotation
    let userLocation: CLLocationCoordinate2D?
    let onContact: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        if let url = lostDog.photoURL {
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
                            Text("LOST: \(lostDog.name)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            Text(lostDog.breed)
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
