import SwiftUI
import CoreLocation

struct RouteStartProximitySheet: View {
    let routeStartLocation: CLLocationCoordinate2D
    let userLocation: CLLocationCoordinate2D?
    let routeName: String
    let onNavigateToStart: () -> Void
    let onStartAnyway: () -> Void
    let onCancel: () -> Void

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
