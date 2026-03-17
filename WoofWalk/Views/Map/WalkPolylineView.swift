import SwiftUI
import MapKit

/// UIViewRepresentable that renders walk polylines on MKMapView with
/// distinct styles for active, planned, guidance, and closing segments,
/// plus paw-print markers every 50 m.
struct WalkPolylineView: UIViewRepresentable {
    let activePoints: [CLLocationCoordinate2D]
    let plannedPoints: [CLLocationCoordinate2D]
    let guidanceCompletedPoints: [CLLocationCoordinate2D]
    let guidanceUpcomingPoints: [CLLocationCoordinate2D]
    let showClosingSegment: Bool
    let showPawMarkers: Bool

    // MARK: - Overlay keys (stored in MKPolyline subclass tag)
    private enum OverlayKind: Int {
        case active = 1
        case planned = 2
        case guidanceCompleted = 3
        case guidanceUpcoming = 4
        case closing = 5
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isRotateEnabled = false
        mapView.showsUserLocation = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays and annotations managed by us
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(
            mapView.annotations.filter { $0 is PawAnnotation }
        )

        addPolyline(to: mapView, points: activePoints, kind: .active)
        addPolyline(to: mapView, points: plannedPoints, kind: .planned)
        addPolyline(to: mapView, points: guidanceCompletedPoints, kind: .guidanceCompleted)
        addPolyline(to: mapView, points: guidanceUpcomingPoints, kind: .guidanceUpcoming)

        // Closing segment: dotted gray from last point back to first
        if showClosingSegment, let first = activePoints.first, let last = activePoints.last {
            addPolyline(to: mapView, points: [last, first], kind: .closing)
        }

        // Paw markers every 50 m along the active track
        if showPawMarkers {
            let pawPositions = pawMarkerCoordinates(along: activePoints, interval: 50)
            for coord in pawPositions {
                let annotation = PawAnnotation(coordinate: coord)
                mapView.addAnnotation(annotation)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Helpers

    private func addPolyline(to mapView: MKMapView, points: [CLLocationCoordinate2D], kind: OverlayKind) {
        guard points.count >= 2 else { return }
        let polyline = TaggedPolyline(coordinates: points, count: points.count)
        polyline.tag = kind.rawValue
        mapView.addOverlay(polyline)
    }

    private func pawMarkerCoordinates(along coords: [CLLocationCoordinate2D], interval: CLLocationDistance) -> [CLLocationCoordinate2D] {
        guard coords.count > 1 else { return [] }
        var markers: [CLLocationCoordinate2D] = []
        var accumulated: CLLocationDistance = 0

        for i in 1..<coords.count {
            let prev = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
            let curr = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            accumulated += curr.distance(from: prev)
            if accumulated >= interval {
                markers.append(coords[i])
                accumulated = 0
            }
        }
        return markers
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? TaggedPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)

            switch OverlayKind(rawValue: polyline.tag) {
            case .active:
                renderer.strokeColor = UIColor(red: 0, green: 0.627, blue: 0.690, alpha: 1) // #00A0B0
                renderer.lineWidth = 5

            case .planned:
                renderer.strokeColor = .purple
                renderer.lineWidth = 4
                renderer.lineDashPattern = [10, 8]

            case .guidanceCompleted:
                renderer.strokeColor = .systemGreen
                renderer.lineWidth = 4

            case .guidanceUpcoming:
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4

            case .closing:
                renderer.strokeColor = .gray
                renderer.lineWidth = 2
                renderer.lineDashPattern = [4, 4]

            case .none:
                renderer.strokeColor = .gray
                renderer.lineWidth = 2
            }

            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is PawAnnotation else { return nil }

            let identifier = "PawMarker"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.image = UIImage(systemName: "pawprint.fill")?
                .withTintColor(UIColor(red: 0, green: 0.627, blue: 0.690, alpha: 1), renderingMode: .alwaysOriginal)
            view.frame.size = CGSize(width: 18, height: 18)
            view.canShowCallout = false
            return view
        }
    }
}

// MARK: - Supporting Types

/// MKPolyline subclass that carries an integer tag for style lookup.
private final class TaggedPolyline: MKPolyline {
    var tag: Int = 0
}

/// Lightweight annotation for paw-print markers.
private final class PawAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}
