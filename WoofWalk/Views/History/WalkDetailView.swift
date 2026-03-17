import SwiftUI
import MapKit

struct WalkDetailView: View {
    let walkId: String
    @StateObject private var viewModel = WalkHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showShareSheet = false

    private var walk: WalkHistory? {
        viewModel.selectedWalk
    }

    private var distanceKm: Double {
        guard let walk = walk else { return 0 }
        return Double(walk.distanceMeters) / 1000.0
    }

    private var formattedDate: String {
        guard let date = walk?.startedAt?.dateValue() else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM dd, yyyy"
        return formatter.string(from: date)
    }

    private var formattedTime: String {
        guard let date = walk?.startedAt?.dateValue() else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var duration: String {
        guard let walk = walk else { return "0m 0s" }
        let hours = walk.durationSec / 3600
        let minutes = (walk.durationSec % 3600) / 60
        let seconds = walk.durationSec % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m \(seconds)s"
    }

    private var pace: Double {
        guard let walk = walk, walk.distanceMeters > 50 && walk.durationSec > 0 else { return 0 }
        return (Double(walk.distanceMeters) / 1000.0) / (Double(walk.durationSec) / 3600.0)
    }

    private var avgSpeed: Double {
        guard let walk = walk, walk.durationSec > 0 else { return 0 }
        return (Double(walk.distanceMeters) / 1000.0) / (Double(walk.durationSec) / 3600.0)
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        walk?.track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading && walk == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let walk = walk {
                    WalkMapSection(coordinates: routeCoordinates)
                        .frame(height: 300)

                    WalkStatisticsSection(
                        date: formattedDate,
                        distanceKm: distanceKm,
                        duration: duration,
                        pace: pace,
                        trackPoints: walk.track.count,
                        avgSpeed: avgSpeed,
                        startTime: formattedTime
                    )
                    .padding()

                    ActionButtonsSection(
                        onExportGpx: {
                            exportWalkGpx()
                        },
                        onShare: {
                            showShareSheet = true
                        }
                    )
                    .padding()
                } else {
                    Text("Walk not found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Walk Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showShareSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Walk", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteWalk()
            }
        } message: {
            Text("Are you sure you want to delete this walk? This action cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let walk = walk {
                ShareSheet(items: [generateShareText(walk: walk)])
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.error ?? "Unknown error")
        }
        .onAppear {
            viewModel.selectWalk(walkId: walkId)
        }
    }

    private func deleteWalk() {
        viewModel.deleteWalk(walkId: walkId)
        dismiss()
    }

    private func exportWalkGpx() {
        viewModel.exportWalkGpx(walkId: walkId)
    }

    private func generateShareText(walk: WalkHistory) -> String {
        let distanceKm = Double(walk.distanceMeters) / 1000.0
        let hours = walk.durationSec / 3600
        let minutes = (walk.durationSec % 3600) / 60
        let speed = avgSpeed

        return """
        Check out my walk on WoofWalk!

        Distance: \(String(format: "%.2f km", distanceKm))
        Duration: \(hours)h \(minutes)m
        Speed: \(String(format: "%.1f km/h", speed))

        #WoofWalk #DogWalking
        """
    }
}

struct WalkMapSection: View {
    let coordinates: [CLLocationCoordinate2D]
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: []) { _ in
            EmptyView()
        }
        .overlay(
            WalkMapPolyline(coordinates: coordinates)
                .stroke(Color.blue, lineWidth: 4)
        )
        .onAppear {
            calculateRegion()
        }
    }

    private func calculateRegion() {
        guard !coordinates.isEmpty else {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            return
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
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLng - minLng) * 1.3
        )

        region = MKCoordinateRegion(center: center, span: span)
    }
}

struct WalkStatisticsSection: View {
    let date: String
    let distanceKm: Double
    let duration: String
    let pace: Double
    let trackPoints: Int
    let avgSpeed: Double
    let startTime: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(date)
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    StatColumn(
                        label: "Distance",
                        value: String(format: "%.2f km", distanceKm)
                    )
                    Spacer()
                    StatColumn(
                        label: "Duration",
                        value: duration
                    )
                    Spacer()
                    StatColumn(
                        label: "Pace",
                        value: String(format: "%.1f min/km", pace)
                    )
                }

                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 0) {
                    StatColumn(
                        label: "Track Points",
                        value: "\(trackPoints)"
                    )
                    Spacer()
                    StatColumn(
                        label: "Avg Speed",
                        value: String(format: "%.1f km/h", avgSpeed)
                    )
                    Spacer()
                    StatColumn(
                        label: "Started",
                        value: startTime
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ActionButtonsSection: View {
    let onExportGpx: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExportGpx) {
                Text("Export GPX")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }

            Button(action: onShare) {
                Text("Share Walk")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
