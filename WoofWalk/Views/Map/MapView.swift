import SwiftUI
import MapKit
import CoreLocation

@available(iOS 17.0, *)
struct MapView: View {
    @StateObject private var viewModel: MapViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPOI: POI?
    @State private var showSearchBar = false
    @State private var showFilterSheet = false
    @State private var showMapClickDialog = false
    @State private var clickedLocation: CLLocationCoordinate2D?
    @State private var isWalkTracking = false
    @State private var showAppGuide = false
    @State private var isTorchOn = false
    @State private var carLocation: CLLocationCoordinate2D?

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, selection: $selectedPOI) {
                if let userLocation = locationManager.location {
                    UserAnnotation()
                }

                ForEach(viewModel.filteredPOIs) { poi in
                    Annotation(poi.title, coordinate: poi.coordinate) {
                        POIMarkerView(poi: poi)
                            .onTapGesture {
                                selectedPOI = poi
                            }
                    }
                }

                if !viewModel.walkPolyline.isEmpty {
                    MapPolyline(coordinates: viewModel.walkPolyline)
                        .stroke(.blue, lineWidth: 5)
                }

                if !viewModel.routePolyline.isEmpty {
                    MapPolyline(coordinates: viewModel.routePolyline)
                        .stroke(.purple, lineWidth: 6)
                }

                if let car = carLocation {
                    Annotation("Car", coordinate: car) {
                        Image(systemName: "car.fill")
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Circle().fill(.white))
                            .shadow(radius: 3)
                    }
                }

                ForEach(viewModel.activeBagDrops) { bagDrop in
                    Annotation("Poo Bag", coordinate: bagDrop.coordinate) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Circle().fill(.white))
                            .shadow(radius: 3)
                    }
                }

                ForEach(viewModel.publicDogs) { dog in
                    Annotation(dog.name, coordinate: dog.coordinate) {
                        Image(systemName: dog.isNervous ? "exclamationmark.triangle.fill" : "pawprint.fill")
                            .foregroundColor(dog.isNervous ? .orange : .blue)
                            .padding(8)
                            .background(Circle().fill(.white))
                            .shadow(radius: 3)
                    }
                }

                ForEach(viewModel.lostDogs) { dog in
                    Annotation("LOST: \(dog.name)", coordinate: dog.coordinate) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Circle().fill(.white))
                            .shadow(radius: 3)
                    }
                }
            }
            .mapStyle(viewModel.mapStyle.mapStyle)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange { context in
                viewModel.onCameraChange(context.region)
            }
            .onTapGesture(coordinateSpace: .local) { location in
                handleMapTap(at: location)
            }

            VStack {
                HStack {
                    MapControls(
                        showSearchBar: $showSearchBar,
                        showFilterSheet: $showFilterSheet,
                        isTorchOn: $isTorchOn,
                        carLocation: $carLocation,
                        onShowGuide: { showAppGuide = true },
                        onLocateUser: {
                            if let location = locationManager.location {
                                cameraPosition = .camera(
                                    MapCamera(
                                        centerCoordinate: location.coordinate,
                                        distance: 1000,
                                        heading: 0,
                                        pitch: 0
                                    )
                                )
                            }
                        },
                        onToggleTorch: {
                            toggleTorch()
                        },
                        onSaveCarLocation: {
                            carLocation = locationManager.location?.coordinate
                        }
                    )
                    Spacer()
                }
                .padding()

                Spacer()

                if isWalkTracking {
                    WalkProgressCard(
                        distance: viewModel.walkDistance,
                        duration: viewModel.walkDuration,
                        onStopWalk: {
                            stopWalk()
                        }
                    )
                    .padding()
                }

                HStack {
                    VStack(spacing: 8) {
                        Button(action: {
                            quickAddBin()
                        }) {
                            Image(systemName: "trash.fill")
                                .padding()
                                .background(Circle().fill(.green))
                                .foregroundColor(.white)
                        }

                        Button(action: {
                            quickAddPooBag()
                        }) {
                            Image(systemName: "bag.fill")
                                .padding()
                                .background(Circle().fill(.orange))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading)

                    Spacer()

                    VStack(spacing: 8) {
                        if isWalkTracking {
                            Button(action: {
                                cycleCameraMode()
                            }) {
                                Image(systemName: viewModel.cameraModeIcon)
                                    .padding()
                                    .background(Circle().fill(.blue))
                                    .foregroundColor(.white)
                            }
                        }

                        Button(action: {
                            showMapClickDialog = true
                        }) {
                            Image(systemName: "plus")
                                .padding(15)
                                .background(Circle().fill(.blue))
                                .foregroundColor(.white)
                        }

                        Button(action: {
                            if isWalkTracking {
                                stopWalk()
                            } else {
                                startWalk()
                            }
                        }) {
                            Image(systemName: isWalkTracking ? "stop.fill" : "play.fill")
                                .padding(15)
                                .background(Circle().fill(isWalkTracking ? .red : .green))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing)
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showSearchBar) {
            SearchBarView(viewModel: viewModel)
        }
        .sheet(isPresented: $showFilterSheet) {
            POIFilterSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showAppGuide) {
            AppGuideView()
        }
        .sheet(item: $selectedPOI) { poi in
            POIDetailSheet(poi: poi, viewModel: viewModel)
        }
        .alert("Map Action", isPresented: $showMapClickDialog) {
            Button("Walk Here") {
                if let location = clickedLocation {
                    walkToLocation(location)
                }
            }
            Button("Create Random Walk") {
                if let location = clickedLocation {
                    createRandomWalk(at: location)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            locationManager.requestLocationPermission()
            viewModel.loadPOIs()
        }
    }

    private func handleMapTap(at location: CGPoint) {
        guard !isWalkTracking else { return }
        clickedLocation = viewModel.convertScreenToCoordinate(location)
        showMapClickDialog = true
    }

    private func startWalk() {
        isWalkTracking = true
        viewModel.startWalkTracking()
    }

    private func stopWalk() {
        isWalkTracking = false
        viewModel.stopWalkTracking()
    }

    private func quickAddBin() {
        guard let location = locationManager.location?.coordinate else { return }
        viewModel.addPOI(type: .bin, at: location)
    }

    private func quickAddPooBag() {
        guard let location = locationManager.location?.coordinate else { return }
        viewModel.addPooBagDrop(at: location)
    }

    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        try? device.lockForConfiguration()
        device.torchMode = isTorchOn ? .off : .on
        isTorchOn.toggle()
        device.unlockForConfiguration()
    }

    private func cycleCameraMode() {
        viewModel.cycleCameraMode()
        updateCameraForMode()
    }

    private func updateCameraForMode() {
        guard let location = locationManager.location?.coordinate else { return }

        switch viewModel.cameraMode {
        case .follow:
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: location,
                    distance: 500,
                    heading: locationManager.heading ?? 0,
                    pitch: 45
                )
            )
        case .overview:
            if !viewModel.walkPolyline.isEmpty {
                let region = calculateBoundingRegion(for: viewModel.walkPolyline)
                cameraPosition = .region(region)
            }
        case .tilt:
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: location,
                    distance: 300,
                    heading: locationManager.heading ?? 0,
                    pitch: 60
                )
            )
        case .free:
            break
        }
    }

    private func calculateBoundingRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLon - minLon) * 1.2
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    private func walkToLocation(_ destination: CLLocationCoordinate2D) {
        guard let origin = locationManager.location?.coordinate else { return }
        viewModel.calculateRoute(from: origin, to: destination)
    }

    private func createRandomWalk(at viaPoint: CLLocationCoordinate2D) {
        guard let origin = locationManager.location?.coordinate else { return }
        viewModel.generateCircularRoute(from: origin, via: viaPoint)
    }

    init(viewModel: MapViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}
