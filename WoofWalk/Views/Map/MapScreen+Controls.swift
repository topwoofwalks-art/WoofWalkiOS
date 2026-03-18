import SwiftUI
import MapKit
import CoreLocation

// MARK: - MapScreen Controls Extension

extension MapScreen {

    // MARK: - Controls Overlay

    var controlsOverlay: some View {
        VStack(spacing: 0) {
            topControls
            Spacer()
            guidanceOrWalkPanel
            Spacer()
            bottomControls
        }
    }

    // MARK: - Top Controls (left to right: car, filter, location, torch, fields, trails)

    var topControls: some View {
        HStack(spacing: 8) {
            Button(action: handleCarButton) {
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundColor(carLocation != nil ? .cyan : .primary)
                    .padding(8)
                    .background(Circle().fill(.regularMaterial))
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

            livestockModeButton

            walkingPathsButton
        }
        .padding()
    }

    // MARK: - Guidance / Walk Panel

    @ViewBuilder
    var guidanceOrWalkPanel: some View {
        if case .active = guidanceViewModel.guidanceState {
            GuidancePanel(
                viewModel: guidanceViewModel,
                onStop: {
                    if walkTrackingViewModel.isWalkActive {
                        stopWalk()
                    }
                    guidanceViewModel.stopGuidance()
                },
                onReroute: {
                    if let userLocation = locationManager.location {
                        guidanceViewModel.requestReroute(from: userLocation)
                    }
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
    }

    // MARK: - Bottom Controls

    var bottomControls: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom) {
                bottomLeftButtons
                Spacer()
                bottomRightButtons
            }

            // Walk button centered at bottom
            VStack(spacing: 6) {
                streakBadge
                walkToggleButton
            }
        }
        .padding()
    }

    // MARK: - Bottom Left (marketplace, bin distance, mark bin)

    var bottomLeftButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            nearestBinCard
            quickAddButton(
                icon: "trash.fill",
                color: .green,
                action: quickAddBin
            )
        }
    }

    @ViewBuilder
    var nearestBinCard: some View {
        if let userLoc = locationManager.location,
           let nearestBin = mapViewModel.filteredPOIs
            .filter({ $0.poiType == .bin })
            .compactMap({ poi -> (POI, Double)? in
                let distance = CLLocation(latitude: poi.lat, longitude: poi.lng)
                    .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
                return (poi, distance)
            })
            .min(by: { $0.1 < $1.1 }) {

            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text(FormatUtils.formatDistance(nearestBin.1))
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Bottom Right (rain mode, pubs, add POI)

    var bottomRightButtons: some View {
        VStack(spacing: 10) {
            rainModeButton
            pubsButton
            addPOIButton
        }
    }

    // MARK: - Rain Mode Button

    @ViewBuilder
    var rainModeButton: some View {
        Button(action: { showRainMode.toggle() }) {
            Image(systemName: showRainMode ? "cloud.rain.fill" : "cloud.rain")
                .font(.body)
                .foregroundColor(showRainMode ? .white : .primary)
                .frame(width: 44, height: 44)
                .background {
                    if showRainMode {
                        Circle().fill(.blue)
                    } else {
                        Circle().fill(.regularMaterial)
                    }
                }
        }
    }

    // MARK: - Streak Badge

    @ViewBuilder
    var streakBadge: some View {
        if walkStreak > 0 {
            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 16))
                Text("\(walkStreak)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 255/255, green: 107/255, blue: 53/255))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            )
        }
    }

    // MARK: - Pubs Button

    var pubsButton: some View {
        Button(action: { showNearbyPubsSheet = true }) {
            Image(systemName: "mug.fill")
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(hex: 0xFF8F00)))
        }
    }

    // MARK: - Livestock Mode Button

    var livestockModeButton: some View {
        Button(action: {
            showLivestockMode.toggle()
            livestockFieldVM.toggleFieldOverlays()
            if showLivestockMode, let loc = locationManager.location {
                Task { await livestockFieldVM.loadFieldsNearby(center: loc) }
            }
        }) {
            Image(systemName: showLivestockMode ? "pawprint.fill" : "pawprint")
                .font(.title3)
                .foregroundColor(showLivestockMode ? .brown : .primary)
                .padding(8)
                .background(Circle().fill(.regularMaterial))
        }
    }

    // MARK: - Walking Paths Button

    var walkingPathsButton: some View {
        Button(action: {
            showWalkingPaths.toggle()
            walkPathVM.togglePathLayer()
            if showWalkingPaths {
                let center = region.center
                let span = region.span
                let bounds = [
                    CLLocationCoordinate2D(latitude: center.latitude - span.latitudeDelta/2, longitude: center.longitude - span.longitudeDelta/2),
                    CLLocationCoordinate2D(latitude: center.latitude + span.latitudeDelta/2, longitude: center.longitude - span.longitudeDelta/2),
                    CLLocationCoordinate2D(latitude: center.latitude + span.latitudeDelta/2, longitude: center.longitude + span.longitudeDelta/2),
                    CLLocationCoordinate2D(latitude: center.latitude - span.latitudeDelta/2, longitude: center.longitude + span.longitudeDelta/2)
                ]
                walkPathVM.loadPathsInViewport(bounds: bounds)
            }
        }) {
            Image(systemName: showWalkingPaths ? "point.topleft.down.to.point.bottomright.curvepath.fill" : "point.topleft.down.to.point.bottomright.curvepath")
                .font(.title3)
                .foregroundColor(showWalkingPaths ? .green : .primary)
                .padding(8)
                .background(Circle().fill(.regularMaterial))
        }
    }

    // MARK: - Individual Buttons

    var addPOIButton: some View {
        Button(action: addPOI) {
            Image(systemName: "plus")
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.blue))
        }
    }

    var plannedWalksButton: some View {
        NavigationLink(value: AppRoute.plannedWalks) {
            Image(systemName: "calendar.badge.clock")
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.turquoise60))
        }
    }

    var walkToggleButton: some View {
        Button(action: toggleWalk) {
            HStack(spacing: 8) {
                Image(systemName: walkTrackingViewModel.isWalkActive ? "stop.fill" : "play.fill")
                    .font(.title3)
                Text(walkTrackingViewModel.isWalkActive ? "Stop" : "Walk")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(walkTrackingViewModel.isWalkActive ? .red : Color(red: 0/255, green: 160/255, blue: 176/255))
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }

    // MARK: - Quick Add Button Helper

    func quickAddButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .padding(12)
                .background(Circle().fill(color))
        }
    }
}

// MARK: - Control Button Style

extension View {
    func controlButtonStyle() -> some View {
        self
            .font(.title3)
            .foregroundColor(.primary)
            .padding(8)
            .background(Circle().fill(.regularMaterial))
    }
}
