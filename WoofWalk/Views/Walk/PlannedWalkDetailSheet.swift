import SwiftUI
import MapKit

struct PlannedWalkDetailSheet: View {
    let walk: PlannedWalk
    let onStartWalk: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    private var routeCoordinates: [CLLocationCoordinate2D] {
        walk.routePolyline.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private var mapRegion: MKCoordinateRegion {
        guard !routeCoordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: walk.startLocation.latitude, longitude: walk.startLocation.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }

        let lats = routeCoordinates.map { $0.latitude }
        let lngs = routeCoordinates.map { $0.longitude }

        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0
        let maxLng = lngs.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.005),
            longitudeDelta: max((maxLng - minLng) * 1.3, 0.005)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Route map preview
                    if !routeCoordinates.isEmpty {
                        routeMapPreview
                    }

                    // Title and location
                    VStack(alignment: .leading, spacing: 6) {
                        Text(walk.title)
                            .font(.title2.bold())

                        if !walk.startLocationName.isEmpty {
                            Label(walk.startLocationName, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Stats chips
                    statsRow
                        .padding(.horizontal)

                    // Description
                    if !walk.description.isEmpty {
                        Text(walk.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    // Notes
                    if !walk.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            ForEach(walk.notes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "note.text")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text(note)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Action buttons
                    VStack(spacing: 10) {
                        Button(action: {
                            onStartWalk()
                            dismiss()
                        }) {
                            Label("Start Walk", systemImage: "figure.walk")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.turquoise60)

                        HStack(spacing: 12) {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Walk Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Delete Walk?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This planned walk will be permanently deleted.")
            }
        }
    }

    // MARK: - Route Map Preview

    private var routeMapPreview: some View {
        Map(coordinateRegion: .constant(mapRegion), annotationItems: []) { (_: EmptyAnnotation) in
            MapMarker(coordinate: CLLocationCoordinate2D())
        }
        .overlay(
            MapRouteOverlay(coordinates: routeCoordinates, region: mapRegion)
        )
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .allowsHitTesting(false)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatChip(
                icon: "arrow.triangle.swap",
                text: FormatUtils.formatDistance(walk.estimatedDistanceMeters)
            )

            StatChip(
                icon: "clock",
                text: FormatUtils.formatDuration(Int(walk.estimatedDurationSec))
            )

            if let date = walk.plannedForDate {
                StatChip(
                    icon: "calendar",
                    text: formatShortDate(date)
                )
            }

            if !walk.routePolyline.isEmpty {
                StatChip(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    text: "\(walk.routePolyline.count) pts"
                )
            }
        }
    }

    private func formatShortDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: date)
    }
}

// MARK: - Stat Chip

private struct StatChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(.systemGray6))
        )
        .foregroundColor(.secondary)
    }
}

// MARK: - Map Route Overlay (draws polyline on SwiftUI Map)

private struct MapRouteOverlay: View {
    let coordinates: [CLLocationCoordinate2D]
    let region: MKCoordinateRegion

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard coordinates.count >= 2 else { return }

                for (index, coord) in coordinates.enumerated() {
                    let point = mapPoint(for: coord, in: geometry.size)
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(Color.turquoise60, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }

    private func mapPoint(for coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let latRange = region.span.latitudeDelta
        let lngRange = region.span.longitudeDelta

        let x = (coordinate.longitude - (region.center.longitude - lngRange / 2)) / lngRange * size.width
        let y = (1 - (coordinate.latitude - (region.center.latitude - latRange / 2)) / latRange) * size.height

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Empty Annotation (for type-safe Map usage)

private struct EmptyAnnotation: Identifiable {
    let id = UUID()
    let coordinate = CLLocationCoordinate2D()
}
