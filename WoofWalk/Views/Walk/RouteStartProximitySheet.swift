import SwiftUI
import CoreLocation

struct RouteStartProximitySheet: View {
    let routeStartLocation: CLLocationCoordinate2D
    let userLocation: CLLocationCoordinate2D?
    let routeName: String
    let onNavigateToStart: () -> Void
    let onStartAnyway: () -> Void
    let onCancel: () -> Void

    /// Optional routing view-model. When provided, the sheet exposes a
    /// Snap-to-paths / As-the-crow-flies segmented toggle that drives
    /// `routingViewModel.routingMode` for the next walk. Mirrors Android
    /// vc 429's `RoutePreviewSheet` toggle. Optional so the sheet is still
    /// usable from contexts that don't own a routing view-model.
    @ObservedObject var routingViewModel: RoutingViewModel

    private var distanceToStart: Double? {
        guard let userLoc = userLocation else { return nil }
        let start = CLLocation(latitude: routeStartLocation.latitude, longitude: routeStartLocation.longitude)
        let user = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return start.distance(from: user)
    }

    private var isNearStart: Bool {
        guard let distance = distanceToStart else { return false }
        return distance < 200 // Within 200m
    }

    /// Surfaced from the most recent routing state. When both Overpass and
    /// OSRM Nearest came up empty for the destination tap we force
    /// crow-flies and disable the snap toggle — matches Android's behaviour
    /// where `RoutePreviewSheet` greys out "Snap to paths" with a
    /// "no walkable paths nearby" hint.
    private var snapFailed: Bool {
        if case .previewReady(let preview) = routingViewModel.routingState {
            return preview.snapFailed
        }
        return false
    }

    private var snapDistanceMeters: Double {
        if case .previewReady(let preview) = routingViewModel.routingState {
            return preview.snapDistanceMeters
        }
        return 0.0
    }

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: isNearStart ? "checkmark.circle.fill" : "location.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(isNearStart ? .green : .orange)

            // Title
            Text(isNearStart ? "You're at the start!" : "You're away from the start")
                .font(.title3.bold())

            // Route info
            VStack(spacing: 4) {
                Text(routeName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let distance = distanceToStart {
                    Text("\(FormatUtils.formatDistance(distance)) from start point")
                        .font(.caption)
                        .foregroundColor(isNearStart ? .green : .orange)
                }
            }

            // Snap-to-paths / Crow-flies segmented toggle. Always rendered
            // so the user can pick the right mode for fields/beaches before
            // starting. Disabled in favour of crow-flies when snap failed.
            // Mirrors Android `RoutePreviewSheet` (vc 429).
            VStack(spacing: 6) {
                // Note: SF Symbols inside `.segmented` Pickers don't always
                // render — UIKit's UISegmentedControl falls back to text on
                // most iOS versions. Keep labels short so both segments fit
                // on narrow phones.
                Picker("Routing", selection: Binding(
                    get: { routingViewModel.routingMode },
                    set: { routingViewModel.setRoutingMode($0) }
                )) {
                    Text("Snap to paths").tag(RoutingMode.snapToRoads)
                    Text("Crow flies").tag(RoutingMode.crowFlies)
                }
                .pickerStyle(.segmented)
                .disabled(snapFailed)

                if snapFailed {
                    Text("No walkable paths nearby — using straight-line route")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                } else if snapDistanceMeters > 50.0 && routingViewModel.routingMode == .snapToRoads {
                    Text("Destination snapped \(Int(snapDistanceMeters)) m to the nearest path")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)

            // Actions
            VStack(spacing: 12) {
                if isNearStart {
                    Button(action: onStartAnyway) {
                        Text("Start Walk")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
                    }
                } else {
                    Button(action: onNavigateToStart) {
                        Label("Navigate to Start", systemImage: "arrow.triangle.turn.up.right.diamond")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
                    }

                    Button(action: onStartAnyway) {
                        Text("Start from here anyway")
                            .font(.subheadline)
                            .foregroundColor(.turquoise60)
                    }
                }

                Button("Cancel", action: onCancel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
        .padding(16)
    }
}
