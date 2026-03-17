import SwiftUI
import CoreLocation

/// Sheet showing dog-friendly pubs nearby, sorted by distance.
struct NearbyPubsSheet: View {
    let pubs: [POI]
    let userLocation: CLLocationCoordinate2D?
    let onSelect: (POI) -> Void
    let onOpenInMaps: (POI) -> Void
    @Environment(\.dismiss) private var dismiss

    private func distance(to poi: POI) -> Double? {
        guard let userLoc = userLocation else { return nil }
        let poiLoc = CLLocation(latitude: poi.lat, longitude: poi.lng)
        let userCLLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return poiLoc.distance(from: userCLLoc)
    }

    private var sortedPubs: [POI] {
        pubs.sorted { (distance(to: $0) ?? .infinity) < (distance(to: $1) ?? .infinity) }
    }

    /// Derive a star rating (1-5) from vote ratio
    private func starRating(for pub: POI) -> Int {
        let total = pub.voteUp + pub.voteDown
        guard total > 0 else { return 3 }
        let ratio = Double(pub.voteUp) / Double(total)
        return max(1, min(5, Int(round(ratio * 5.0))))
    }

    var body: some View {
        NavigationView {
            Group {
                if sortedPubs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mug.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.neutral60)
                        Text("No dog-friendly pubs nearby")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try zooming out or moving to a different area.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(sortedPubs, id: \.id) { pub in
                        Button {
                            onSelect(pub)
                            dismiss()
                        } label: {
                            pubRow(pub)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                onOpenInMaps(pub)
                            } label: {
                                Label("Maps", systemImage: "map.fill")
                            }
                            .tint(.turquoise60)
                        }
                    }
                }
            }
            .navigationTitle("Nearby Pubs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Row

    private func pubRow(_ pub: POI) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "mug.fill")
                .foregroundColor(.white)
                .font(.system(size: 16))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(hex: 0xFF8F00)))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(pub.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                // Star rating
                HStack(spacing: 2) {
                    let rating = starRating(for: pub)
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(star <= rating ? .orange60 : .neutral70)
                    }
                }

                if !pub.formattedAddress.isEmpty {
                    Text(pub.formattedAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right side: badge + distance
            VStack(alignment: .trailing, spacing: 4) {
                // Dog-friendly badge
                HStack(spacing: 3) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 9))
                    Text("Dog Friendly")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.turquoise60)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.turquoise90.opacity(0.3))
                )

                if let dist = distance(to: pub) {
                    Text(FormatUtils.formatDistance(dist))
                        .font(.caption)
                        .foregroundColor(.turquoise60)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
