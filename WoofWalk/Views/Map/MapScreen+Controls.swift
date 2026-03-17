import SwiftUI
import MapKit

// MARK: - MapScreen Controls Extension

extension MapScreen {

    // MARK: - Controls Overlay

    var controlsOverlay: some View {
        VStack {
            topControls
            Spacer()
            guidanceOrWalkPanel
            Spacer()
            bottomControls
        }
    }

    // MARK: - Top Controls

    var topControls: some View {
        HStack(alignment: .top, spacing: 12) {
            compassView
            Spacer()
            topRightControls
        }
        .padding()
    }

    // MARK: - Compass View (replaces helpButton)

    var compassView: some View {
        Button(action: { centerOnUser() }) {
            Image(systemName: "location.north.fill")
                .font(.title3)
                .rotationEffect(.degrees(-locationManager.bearing))
                .foregroundColor(.primary)
                .padding(10)
                .background(Circle().fill(.regularMaterial))
        }
        .animation(.easeInOut(duration: 0.3), value: locationManager.bearing)
    }

    // MARK: - Top Right Controls

    var topRightControls: some View {
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
        HStack(alignment: .bottom) {
            bottomLeftButtons
            Spacer()
            bottomRightButtons
        }
        .padding()
    }

    var bottomLeftButtons: some View {
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
    }

    @ViewBuilder
    var bottomRightButtons: some View {
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

            // Livestock mode toggle
            livestockModeButton

            // Walking paths toggle
            walkingPathsButton

            addPOIButton
            planningModeButton

            // Streak badge (shown above walk toggle when streak > 0)
            streakBadge

            walkToggleButton
        }
    }

    // MARK: - Streak Badge

    @ViewBuilder
    var streakBadge: some View {
        if walkStreak > 0 {
            HStack(spacing: 4) {
                Text("\u{1F525}")
                Text("\(walkStreak)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 255/255, green: 107/255, blue: 53/255))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }

    // MARK: - Livestock Mode Button

    var livestockModeButton: some View {
        Button(action: { showLivestockMode.toggle() }) {
            Image(systemName: showLivestockMode ? "hare.fill" : "hare")
                .font(.title3)
                .foregroundColor(.white)
                .padding(12)
                .background(Circle().fill(showLivestockMode ? .brown : .blue.opacity(0.8)))
        }
    }

    // MARK: - Walking Paths Button

    var walkingPathsButton: some View {
        Button(action: { showWalkingPaths.toggle() }) {
            Image(systemName: showWalkingPaths ? "point.topleft.down.to.point.bottomright.curvepath.fill" : "point.topleft.down.to.point.bottomright.curvepath")
                .font(.title3)
                .foregroundColor(.white)
                .padding(12)
                .background(Circle().fill(showWalkingPaths ? .green : .blue.opacity(0.8)))
        }
    }

    // MARK: - Individual Buttons

    var addPOIButton: some View {
        Button(action: addPOI) {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(.white)
                .padding(16)
                .background(Circle().fill(.blue))
        }
    }

    var planningModeButton: some View {
        Button(action: { isPlanningMode.toggle() }) {
            Image(systemName: isPlanningMode ? "pencil.circle.fill" : "pencil.circle")
                .font(.title2)
                .foregroundColor(.white)
                .padding(16)
                .background(Circle().fill(isPlanningMode ? .orange : .blue.opacity(0.8)))
        }
    }

    var walkToggleButton: some View {
        Button(action: toggleWalk) {
            Image(systemName: walkTrackingViewModel.isWalkActive ? "stop.fill" : "play.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(16)
                .background(Circle().fill(walkTrackingViewModel.isWalkActive ? .red : .green))
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
