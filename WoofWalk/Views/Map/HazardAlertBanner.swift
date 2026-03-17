import SwiftUI
import CoreLocation

struct HazardAlertBanner: View {
    let hazard: HazardReport
    let userLocation: CLLocationCoordinate2D?
    let onReroute: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        if isVisible {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Text(hazard.hazardType.emoji)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hazard.hazardType.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)

                        Text(distanceText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()
                }

                if !hazard.description.isEmpty {
                    Text(hazard.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        dismiss()
                        onReroute()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            Text("Reroute")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(bannerColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white))
                    }

                    Button(action: dismiss) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Dismiss")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().stroke(.white, lineWidth: 1.5))
                    }

                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(bannerColor)
                    .shadow(color: bannerColor.opacity(0.4), radius: 8, y: 4)
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var bannerColor: Color {
        hazard.hazardSeverity.color
    }

    private var distanceText: String {
        guard let userLocation = userLocation else {
            return "Nearby hazard reported"
        }
        let meters = hazard.distance(from: userLocation)
        if meters < 1000 {
            return "\(Int(meters))m ahead"
        } else {
            let km = meters / 1000.0
            return String(format: "%.1fkm ahead", km)
        }
    }

    private func dismiss() {
        autoDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    func show() -> HazardAlertBanner {
        var copy = self
        copy._isVisible = State(initialValue: true)
        return copy
    }
}

// MARK: - Hazard Alert Banner Container

/// Manages display of hazard alert banners, showing one at a time
struct HazardAlertBannerContainer: View {
    let hazards: [HazardReport]
    let userLocation: CLLocationCoordinate2D?
    let onReroute: (HazardReport) -> Void
    @Binding var dismissedHazardIds: Set<String>

    var body: some View {
        if let activeHazard = nearestUndismissedHazard {
            HazardAlertBanner(
                hazard: activeHazard,
                userLocation: userLocation,
                onReroute: { onReroute(activeHazard) },
                onDismiss: {
                    if let id = activeHazard.id {
                        dismissedHazardIds.insert(id)
                    }
                }
            )
            .show()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: activeHazard.id)
        }
    }

    private var nearestUndismissedHazard: HazardReport? {
        hazards
            .filter { hazard in
                guard let id = hazard.id else { return false }
                guard !dismissedHazardIds.contains(id) else { return false }
                guard !hazard.isExpired else { return false }
                guard let loc = userLocation else { return false }
                return hazard.isWithinAlertRange(of: loc)
            }
            .sorted { a, b in
                guard let loc = userLocation else { return false }
                return a.distance(from: loc) < b.distance(from: loc)
            }
            .first
    }
}
