import SwiftUI
import MapKit

@MainActor
class MapSnapshotCache: ObservableObject {
    static let shared = MapSnapshotCache()

    private var cache: [String: UIImage] = [:]
    private let maxCacheSize = 50

    func getSnapshot(for points: [CLLocationCoordinate2D], size: CGSize = CGSize(width: 400, height: 200)) async -> UIImage? {
        let key = cacheKey(points: points, size: size)
        if let cached = cache[key] { return cached }

        guard !points.isEmpty else { return nil }

        let region = regionForPoints(points)
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            let image = drawRoute(on: snapshot, points: points)

            if cache.count >= maxCacheSize {
                cache.removeAll()
            }
            cache[key] = image
            return image
        } catch {
            print("Map snapshot error: \(error)")
            return nil
        }
    }

    private func drawRoute(on snapshot: MKMapSnapshotter.Snapshot, points: [CLLocationCoordinate2D]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)

            let path = UIBezierPath()
            for (index, point) in points.enumerated() {
                let cgPoint = snapshot.point(for: point)
                if index == 0 {
                    path.move(to: cgPoint)
                } else {
                    path.addLine(to: cgPoint)
                }
            }

            UIColor.systemBlue.setStroke()
            path.lineWidth = 3.0
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    private func regionForPoints(_ points: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = points[0].latitude
        var maxLat = points[0].latitude
        var minLng = points[0].longitude
        var maxLng = points[0].longitude

        for point in points {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLng = min(minLng, point.longitude)
            maxLng = max(maxLng, point.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3 + 0.002,
            longitudeDelta: (maxLng - minLng) * 1.3 + 0.002
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func cacheKey(points: [CLLocationCoordinate2D], size: CGSize) -> String {
        let coordStr = points.prefix(5).map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
        return "\(coordStr)_\(Int(size.width))x\(Int(size.height))_\(points.count)"
    }

    func clearCache() {
        cache.removeAll()
    }
}
