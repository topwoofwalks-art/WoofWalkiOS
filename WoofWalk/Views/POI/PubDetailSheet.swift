import SwiftUI
import CoreLocation

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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with pub icon
                    HStack(spacing: 12) {
                        Image(systemName: "mug.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange60)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.orange90))

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

                    // Distance
                    if let dist = distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(FormatUtils.formatDistance(dist))
                                .font(.subheadline)
                        }
                        .foregroundColor(.turquoise60)
                    }

                    // Description
                    if !poi.desc.isEmpty {
                        Text(poi.desc)
                            .font(.body)
                    }

                    // Dog-friendly info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Dog-friendly pub", systemImage: "pawprint.fill")
                            .font(.subheadline)
                            .foregroundColor(.turquoise60)

                        if let access = poi.access {
                            if !access.notes.isEmpty {
                                Text(access.notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.turquoise90.opacity(0.2)))

                    // Photos
                    if !poi.photoUrls.isEmpty {
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

                    // Votes
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

                    // Navigate button
                    Button(action: onNavigate) {
                        Label("Walk Here", systemImage: "figure.walk")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
                    }
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
}
