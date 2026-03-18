import SwiftUI
import CoreLocation

struct PlanningModeOverlay: View {
    @Binding var isActive: Bool
    let waypoints: [CLLocationCoordinate2D]
    let estimatedDistance: Double // meters
    let estimatedDuration: Int // seconds
    let isLoopClosed: Bool
    let canCloseLoop: Bool // 3+ waypoints and not already closed
    let closingSegmentPreview: [CLLocationCoordinate2D]
    let mapCenterCoordinate: CLLocationCoordinate2D
    let isFetchingRoute: Bool
    @Binding var useFootpathRouting: Bool
    let onAddWaypoint: (CLLocationCoordinate2D) -> Void
    let onRemoveLastWaypoint: () -> Void
    let onClearAll: () -> Void
    let onCloseLoop: () -> Void
    let onSave: () -> Void
    let onStartWalk: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            // Top instruction bar
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.turquoise60)
                Text("Pan map, then tap Drop Pin")
                    .font(.subheadline)
                Spacer()
                Button(action: { onAddWaypoint(mapCenterCoordinate) }) {
                    Label("Drop Pin", systemImage: "mappin")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.turquoise60))
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal)

            Spacer()

            // Crosshair at map center
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.turquoise60.opacity(0.8))
                .shadow(color: .white, radius: 2)

            Spacer()

            // Bottom panel with stats and actions
            if !waypoints.isEmpty {
                VStack(spacing: 12) {
                    // Route stats
                    HStack(spacing: 24) {
                        VStack {
                            Text(FormatUtils.formatDistance(estimatedDistance))
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Distance")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text(FormatUtils.formatDuration(estimatedDuration))
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Est. Time")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(waypoints.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Waypoints")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Loop status
                    if isLoopClosed {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Loop closed")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    // Footpath routing toggle
                    HStack(spacing: 8) {
                        Image(systemName: useFootpathRouting ? "figure.walk" : "line.diagonal")
                            .font(.caption)
                            .foregroundColor(useFootpathRouting ? .turquoise60 : .secondary)
                        Toggle(isOn: $useFootpathRouting) {
                            Text(useFootpathRouting ? "Walking route" : "Straight line")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .turquoise60))

                        if isFetchingRoute {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    // Action buttons - row 1: Undo, Close Loop, Clear All
                    HStack(spacing: 8) {
                        Button(action: onRemoveLastWaypoint) {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.neutral90))
                                .foregroundColor(.neutral30)
                        }

                        if canCloseLoop {
                            Button(action: onCloseLoop) {
                                Label("Close Loop", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.turquoise90))
                                    .foregroundColor(.turquoise30)
                            }
                        }

                        Button(action: onClearAll) {
                            Label("Clear All", systemImage: "trash")
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.red.opacity(0.15)))
                                .foregroundColor(.red)
                        }
                    }

                    // Action buttons - row 2: Save, Start Walk
                    HStack(spacing: 12) {
                        Button(action: onSave) {
                            Label("Save", systemImage: "square.and.arrow.down")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.turquoise90))
                                .foregroundColor(.turquoise30)
                        }

                        Button(action: onStartWalk) {
                            Label("Start Walk", systemImage: "figure.walk")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.turquoise60))
                                .foregroundColor(.white)
                        }
                    }

                    Button("Cancel", action: onCancel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(radius: 4)
                )
                .padding(.horizontal)
            }
        }
    }
}
