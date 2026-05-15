import SwiftUI
import MapKit
import CoreLocation

// MARK: - POIClusteredMapView
//
// MapKit-native POI clustering layer. Parity with Android
// `PoiClusterRenderer.kt` — the dense-POI UX issue in central London
// (50+ POIs in one screenful) gets solved by MapKit's first-party
// `MKMarkerAnnotationView.clusteringIdentifier` clustering.
//
// SwiftUI's `Map` view does not expose `clusteringIdentifier`. This
// component is a `UIViewRepresentable` wrapping `MKMapView` so the
// native clustering pipeline is available.
//
// Wire-up pattern (additive, no edit to the existing `MapScreen`
// SwiftUI Map):
//
// ```swift
// POIClusteredMapView(
//     region: $region,
//     pois: mapViewModel.filteredPOIs,
//     onSelectPoi: { poi in ... },
//     onSelectCluster: { cluster in
//         selectedCluster = AnnotationCluster(
//             coordinate: cluster.coordinate,
//             annotations: cluster.memberAnnotations.compactMap {
//                 ($0 as? POIAnnotation).map { ann in
//                     CustomAnnotation(title: ann.title ?? "",
//                                      coordinate: ann.coordinate,
//                                      type: .poi(ann.poi))
//                 }
//             }
//         )
//         showClusterSelectionSheet = true
//     }
// )
// ```
//
// The `onSelectCluster` callback bridges to the existing
// `ClusterPoiSelectionSheet` — same UX as the SwiftUI path.
struct POIClusteredMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let pois: [POI]
    let onSelectPoi: (POI) -> Void
    let onSelectCluster: (MKClusterAnnotation) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        // Register both the leaf marker and the cluster view types
        // ahead of time so the delegate doesn't have to lazy-init
        // them in the hot path.
        mapView.register(
            POIMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: POIMarkerAnnotationView.reuseId
        )
        mapView.register(
            POIClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: POIClusterAnnotationView.reuseId
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Region sync — guard against echo loops by comparing to a
        // tolerance window.
        let current = mapView.region
        let dLat = abs(current.center.latitude - region.center.latitude)
        let dLng = abs(current.center.longitude - region.center.longitude)
        let dSpan = abs(current.span.latitudeDelta - region.span.latitudeDelta)
        if dLat > 0.0001 || dLng > 0.0001 || dSpan > 0.0001 {
            mapView.setRegion(region, animated: true)
        }

        // Annotation diffing — replace if the POI id set changes.
        let existingIds = Set(mapView.annotations.compactMap { ($0 as? POIAnnotation)?.poi.id })
        let newIds = Set(pois.map { $0.id })
        if existingIds != newIds {
            let toRemove = mapView.annotations.compactMap { $0 as? POIAnnotation }
            mapView.removeAnnotations(toRemove)
            let toAdd = pois.map { POIAnnotation(poi: $0) }
            mapView.addAnnotations(toAdd)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        let parent: POIClusteredMapView

        init(parent: POIClusteredMapView) {
            self.parent = parent
        }

        // MARK: Annotation View Provider

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Cluster view branch — surfaces a circular cluster pin
            // with the member count + a paw-tinted icon. Tapping
            // forwards to `onSelectCluster` so the parent screen can
            // present the existing `ClusterPoiSelectionSheet`.
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: POIClusterAnnotationView.reuseId,
                    for: cluster
                ) as? POIClusterAnnotationView
                view?.configure(with: cluster)
                return view
            }

            // Leaf POI marker. The native clustering kicks in
            // automatically because `clusteringIdentifier` is set
            // inside POIMarkerAnnotationView.
            if let poiAnn = annotation as? POIAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: POIMarkerAnnotationView.reuseId,
                    for: poiAnn
                ) as? POIMarkerAnnotationView
                view?.configure(with: poiAnn.poi)
                return view
            }

            return nil
        }

        // MARK: Selection

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Cluster tap → forward to the existing selection sheet
            // wire-up. Mirrors the Android cluster-tap behaviour.
            if let cluster = view.annotation as? MKClusterAnnotation {
                parent.onSelectCluster(cluster)
                mapView.deselectAnnotation(cluster, animated: false)
                return
            }
            if let poiAnn = view.annotation as? POIAnnotation {
                parent.onSelectPoi(poiAnn.poi)
                mapView.deselectAnnotation(poiAnn, animated: false)
            }
        }

        // MARK: Region sync back to SwiftUI

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

// MARK: - POIAnnotation (MKAnnotation wrapper)

final class POIAnnotation: NSObject, MKAnnotation {
    let poi: POI
    var coordinate: CLLocationCoordinate2D { poi.coordinate }
    var title: String? { poi.title }
    var subtitle: String? { poi.desc }

    init(poi: POI) {
        self.poi = poi
    }
}

// MARK: - POIMarkerAnnotationView

/// The leaf POI annotation view. Sets `clusteringIdentifier = "poi"`
/// so MapKit's native clustering rolls dense POI groups up into
/// `MKClusterAnnotation` automatically as the map zooms.
final class POIMarkerAnnotationView: MKMarkerAnnotationView {
    static let reuseId = "POIMarkerAnnotationView"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "poi"
        displayPriority = .defaultHigh
        canShowCallout = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with poi: POI) {
        clusteringIdentifier = "poi"
        glyphImage = UIImage(systemName: poi.poiType.iconName)
        markerTintColor = UIColor(PoiTypeColors.color(for: poi.poiType))
    }
}

// MARK: - POIClusterAnnotationView

/// Cluster bubble shown when MapKit rolls multiple POIs into one
/// annotation. Tapping it bubbles to `onSelectCluster` (see the
/// coordinator).
final class POIClusterAnnotationView: MKAnnotationView {
    static let reuseId = "POIClusterAnnotationView"

    private let countLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        backgroundColor = .clear
        addSubview(countLabel)
        NSLayoutConstraint.activate([
            countLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        canShowCallout = false
        displayPriority = .defaultHigh
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        // Outer ring — accent colour
        let accent = UIColor.systemTeal.withAlphaComponent(0.95)
        accent.setFill()
        ctx.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
        // Inner white halo
        UIColor.white.setStroke()
        ctx.setLineWidth(2.5)
        ctx.strokeEllipse(in: rect.insetBy(dx: 3, dy: 3))
    }

    func configure(with cluster: MKClusterAnnotation) {
        countLabel.text = "\(cluster.memberAnnotations.count)"
        setNeedsDisplay()
    }
}
