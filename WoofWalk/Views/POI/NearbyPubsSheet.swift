import SwiftUI
import CoreLocation

struct NearbyPubsSheet: View {
    let pubs: [POI]
    let userLocation: CLLocationCoordinate2D?
    let onSelect: (POI) -> Void
    @Environment(\.dismiss) private var dismiss

    private func distance(to poi: POI) -> Double? {
        guard let userLoc = userLocation else { return nil }
        let poiLoc = CLLocation(latitude: poi.lat, longitude: poi.lng)
        let userCLLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return poiLoc.distance(from: userCLLoc)
    }

    var sortedPubs: [POI] {
        pubs.sorted { (distance(to: $0) ?? .infinity) < (distance(to: $1) ?? .infinity) }
    }

    var body: some View {
        NavigationView {
            List(sortedPubs, id: \.id) { pub in
                Button(action: { onSelect(pub); dismiss() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "mug.fill")
                            .foregroundColor(.orange60)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.orange90))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pub.title).font(.subheadline.bold())
                            if !pub.formattedAddress.isEmpty {
                                Text(pub.formattedAddress).font(.caption).foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if let dist = distance(to: pub) {
                            Text(FormatUtils.formatDistance(dist))
                                .font(.caption)
                                .foregroundColor(.turquoise60)
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
}
