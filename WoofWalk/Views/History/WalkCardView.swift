import SwiftUI
import MapKit

struct WalkCardView: View {
    let walk: WalkHistory
    let onClick: () -> Void

    private var distanceKm: Double {
        Double(walk.distanceMeters) / 1000.0
    }

    private var formattedDate: String {
        guard let date = walk.startedAt?.dateValue() else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy - HH:mm"
        return formatter.string(from: date)
    }

    private var duration: String {
        let hours = walk.durationSec / 3600
        let minutes = (walk.durationSec % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var speed: Double {
        guard walk.distanceMeters > 50 && walk.durationSec > 0 else { return 0.0 }
        return (Double(walk.distanceMeters) / 1000.0) / (Double(walk.durationSec) / 3600.0)
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        walk.track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 0) {
                if !routeCoordinates.isEmpty {
                    WalkMapThumbnail(coordinates: routeCoordinates)
                        .frame(height: 120)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(formattedDate)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 0) {
                        StatColumn(label: "Distance", value: String(format: "%.2f km", distanceKm))
                        Spacer()
                        StatColumn(label: "Duration", value: duration)
                        Spacer()
                        StatColumn(label: "Speed", value: String(format: "%.1f km/h", speed))
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct WalkMapThumbnail: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        Map(coordinateRegion: .constant(region))
        .overlay(
            WalkMapPolyline(coordinates: coordinates)
                .stroke(Color.blue, lineWidth: 3)
        )
        .disabled(true)
    }

    private var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLng - minLng) * 1.2
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

struct WalkMapPolyline: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !coordinates.isEmpty else { return path }

        let region = calculateRegion()
        let latDelta = region.span.latitudeDelta
        let lngDelta = region.span.longitudeDelta

        for (index, coordinate) in coordinates.enumerated() {
            let x = CGFloat((coordinate.longitude - region.center.longitude + lngDelta / 2) / lngDelta) * rect.width
            let y = CGFloat((region.center.latitude - coordinate.latitude + latDelta / 2) / latDelta) * rect.height

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func calculateRegion() -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        let lats = coordinates.map { $0.latitude }
        let lngs = coordinates.map { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLng - minLng) * 1.2
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

struct StatColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.body)
                .fontWeight(.medium)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
