import SwiftUI
import MapKit

struct CompletionMapView: UIViewRepresentable {
    let trackPoints: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator
        mapView.layer.cornerRadius = 16
        mapView.clipsToBounds = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard trackPoints.count >= 2 else { return }

        // Route polyline
        let polyline = MKPolyline(coordinates: trackPoints, count: trackPoints.count)
        mapView.addOverlay(polyline)

        // Start pin (green)
        let startPin = MKPointAnnotation()
        startPin.coordinate = trackPoints.first!
        startPin.title = "Start"
        mapView.addAnnotation(startPin)

        // End pin (red)
        let endPin = MKPointAnnotation()
        endPin.coordinate = trackPoints.last!
        endPin.title = "End"
        mapView.addAnnotation(endPin)

        // Fit camera to polyline bounds
        let rect = polyline.boundingMapRect
        let insets = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        mapView.setVisibleMapRect(rect, edgePadding: insets, animated: false)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1.0) // turquoise
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pointAnnotation = annotation as? MKPointAnnotation else { return nil }
            let identifier = pointAnnotation.title ?? "pin"
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.displayPriority = .required
            if pointAnnotation.title == "Start" {
                view.markerTintColor = .systemGreen
                view.glyphImage = UIImage(systemName: "flag.fill")
            } else {
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "flag.checkered")
            }
            return view
        }
    }
}

struct CompletionMapSection: View {
    let trackPoints: [CLLocationCoordinate2D]

    var body: some View {
        CompletionMapView(trackPoints: trackPoints)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.horizontal)
    }
}
