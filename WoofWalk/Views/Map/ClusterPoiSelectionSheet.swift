import SwiftUI
import CoreLocation

/// Sheet displayed when tapping a cluster at max zoom, listing all POIs in the cluster.
struct ClusterPoiSelectionSheet: View {
    let cluster: AnnotationCluster
    let userLocation: CLLocationCoordinate2D?
    let onSelectPoi: (POI) -> Void
    @Environment(\.dismiss) private var dismiss

    private var poiAnnotations: [(annotation: CustomAnnotation, poi: POI)] {
        cluster.annotations.compactMap { annotation in
            if case .poi(let poi) = annotation.type {
                return (annotation, poi)
            }
            return nil
        }
    }

    private func distance(to poi: POI) -> Double? {
        guard let userLoc = userLocation else { return nil }
        let poiLoc = CLLocation(latitude: poi.lat, longitude: poi.lng)
        let userCLLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return poiLoc.distance(from: userCLLoc)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(poiAnnotations, id: \.poi.id) { item in
                    Button {
                        onSelectPoi(item.poi)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.poi.poiType.iconName)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle().fill(PoiTypeColors.color(for: item.poi.poiType))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.poi.title)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Text(item.poi.poiType.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if let dist = distance(to: item.poi) {
                                Text(FormatUtils.formatDistance(dist))
                                    .font(.caption)
                                    .foregroundColor(.turquoise60)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("\(cluster.count) POIs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
