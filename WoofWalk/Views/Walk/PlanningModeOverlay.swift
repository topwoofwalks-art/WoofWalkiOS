import SwiftUI
import CoreLocation

struct PlanningModeOverlay: View {
    @Binding var isActive: Bool
    let waypoints: [CLLocationCoordinate2D]
    let estimatedDistance: Double // meters
    let estimatedDuration: Int // seconds
    let onAddWaypoint: (CLLocationCoordinate2D) -> Void
    let onRemoveLastWaypoint: () -> Void
    let onSave: () -> Void
    let onStartWalk: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            // Top instruction bar
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundColor(.turquoise60)
                Text("Tap map to add waypoints")
                    .font(.subheadline)
                Spacer()
                Button("Done", action: { isActive = false })
                    .font(.subheadline.bold())
                    .foregroundColor(.turquoise60)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal)

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

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: onRemoveLastWaypoint) {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.neutral90))
                                .foregroundColor(.neutral30)
                        }

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
