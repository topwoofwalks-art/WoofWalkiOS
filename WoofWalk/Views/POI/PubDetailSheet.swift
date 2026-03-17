import SwiftUI
import CoreLocation
import MapKit

/// Detail sheet for a dog-friendly pub with amenities, photos, and action buttons.
struct PubDetailSheet: View {
    let poi: POI
    let userLocation: CLLocationCoordinate2D?
    let onNavigate: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var distance: Double? {
        guard let userLoc = userLocation else { return nil }
        let poiLoc = CLLocation(latitude: poi.lat, longitude: poi.lng)
        let userCLLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return poiLoc.distance(from: userCLLoc)
    }

    private var starRating: Int {
        let total = poi.voteUp + poi.voteDown
        guard total > 0 else { return 3 }
        let ratio = Double(poi.voteUp) / Double(total)
        return max(1, min(5, Int(round(ratio * 5.0))))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pubHeader
                    ratingRow
                    distanceLabel
                    dogFriendlyBadge
                    descriptionText
                    amenitiesSection
                    photoGallery
                    votesRow
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Pub Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var pubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "mug.fill")
                .font(.largeTitle)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(hex: 0xFF8F00)))

            VStack(alignment: .leading, spacing: 4) {
                Text(poi.title)
                    .font(.title2.bold())
                if !poi.formattedAddress.isEmpty {
                    Text(poi.formattedAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Rating

    private var ratingRow: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= starRating ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundColor(star <= starRating ? .orange60 : .neutral70)
            }
            Text("(\(poi.voteUp + poi.voteDown) votes)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
    }

    // MARK: - Distance

    @ViewBuilder
    private var distanceLabel: some View {
        if let dist = distance {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text(FormatUtils.formatDistance(dist))
                    .font(.subheadline)
            }
            .foregroundColor(.turquoise60)
        }
    }

    // MARK: - Dog Friendly Badge

    private var dogFriendlyBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.title3)
                .foregroundColor(.turquoise60)

            VStack(alignment: .leading, spacing: 2) {
                Text("Dog-Friendly Pub")
                    .font(.subheadline.bold())
                    .foregroundColor(.turquoise40)

                if let access = poi.access, !access.notes.isEmpty {
                    Text(access.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.turquoise90.opacity(0.2))
        )
    }

    // MARK: - Description

    @ViewBuilder
    private var descriptionText: some View {
        if !poi.desc.isEmpty {
            Text(poi.desc)
                .font(.body)
        }
    }

    // MARK: - Amenities

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amenities")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                amenityChip(icon: "drop.fill", label: "Water Bowl")
                amenityChip(icon: "leaf.fill", label: "Garden Area")
                amenityChip(icon: "gift.fill", label: "Dog Treats")
                amenityChip(icon: "sun.max.fill", label: "Outdoor Seating")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.neutral95.opacity(0.5))
        )
    }

    private func amenityChip(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.turquoise60)
            Text(label)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.turquoise90.opacity(0.15))
        )
    }

    // MARK: - Photos

    @ViewBuilder
    private var photoGallery: some View {
        if !poi.photoUrls.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Photos")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(poi.photoUrls, id: \.self) { urlStr in
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } placeholder: {
                                    Rectangle().fill(Color.neutral90)
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Votes

    private var votesRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "hand.thumbsup.fill")
                Text("\(poi.voteUp)")
            }
            .foregroundColor(.green)

            HStack(spacing: 4) {
                Image(systemName: "hand.thumbsdown.fill")
                Text("\(poi.voteDown)")
            }
            .foregroundColor(.red)
        }
        .font(.subheadline)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Walk Here
            Button(action: onNavigate) {
                Label("Walk Here", systemImage: "figure.walk")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
            }

            HStack(spacing: 10) {
                // Directions in Apple Maps
                Button(action: openInMaps) {
                    Label("Directions", systemImage: "map.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.turquoise60)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.turquoise60, lineWidth: 1.5)
                        )
                }

                // Call (if address suggests a phone might be available)
                Button(action: openInMaps) {
                    Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange60)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange60, lineWidth: 1.5)
                        )
                }
            }
        }
    }

    // MARK: - Actions

    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: poi.lat, longitude: poi.lng)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = poi.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}
