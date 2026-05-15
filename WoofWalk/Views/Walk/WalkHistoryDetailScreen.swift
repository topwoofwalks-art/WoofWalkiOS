import SwiftUI
import MapKit

struct WalkHistoryDetailScreen: View {
    let walkId: String
    @StateObject private var viewModel = WalkHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false

    private var walk: WalkHistory? { viewModel.selectedWalk }

    // MARK: - Computed Properties

    private var formattedDate: String {
        guard let date = walk?.startedAt?.dateValue() else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var formattedTime: String {
        guard let date = walk?.startedAt?.dateValue() else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private var distanceKm: Double {
        Double(walk?.distanceMeters ?? 0) / 1000.0
    }

    private var durationText: String {
        let sec = walk?.durationSec ?? 0
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m \(s)s"
    }

    private var paceMinPerKm: Double {
        guard let w = walk, w.distanceMeters > 50, w.durationSec > 0 else { return 0 }
        let km = Double(w.distanceMeters) / 1000.0
        return (Double(w.durationSec) / 60.0) / km
    }

    private var speedKmh: Double {
        guard let w = walk, w.durationSec > 0 else { return 0 }
        return (Double(w.distanceMeters) / 1000.0) / (Double(w.durationSec) / 3600.0)
    }

    private var elevationGain: Double {
        // Surfaced from the walk doc — computed at tracking time from
        // CLLocation altitudes and persisted on the walk so the detail
        // screen doesn't have to re-derive it from a track that may
        // not carry per-point altitude. Legacy walks pre-elevation-
        // tracking won't have the field — fall through to 0.
        return Double(walk?.elevGainM ?? 0)
    }

    private var trackCoordinates: [CLLocationCoordinate2D] {
        walk?.track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) } ?? []
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading && walk == nil {
                    ProgressView("Loading walk...")
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let walk = walk {
                    // Route map
                    if !trackCoordinates.isEmpty {
                        CompletionMapView(trackPoints: trackCoordinates)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                            .padding(.top, 8)
                    } else {
                        noMapPlaceholder
                    }

                    // Date and time header
                    VStack(spacing: 4) {
                        Text(formattedDate)
                            .font(.title3.bold())
                        Text("Started at \(formattedTime)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)

                    // Stats grid
                    statsGrid
                        .padding()

                    // Dog photos row
                    if !walk.dogIds.isEmpty {
                        dogPhotosSection(dogIds: walk.dogIds)
                            .padding(.horizontal)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Walk not found")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
        }
        .navigationTitle("Walk Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showShareSheet = true } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button { viewModel.exportWalkGpx(walkId: walkId) } label: {
                        Label("Export GPX", systemImage: "arrow.down.doc")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete Walk", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Walk", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteWalk(walkId: walkId)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this walk? This cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let walk = walk {
                ShareSheet(activityItems: [shareText(for: walk)])
            }
        }
        .onAppear {
            viewModel.selectWalk(walkId: walkId)
        }
    }

    // MARK: - Subviews

    private var noMapPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray6))
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 36))
                    Text("No route data")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            )
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private var statsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                DetailStatCell(icon: "point.topleft.down.to.point.bottomright.curvepath",
                               label: "Distance", value: String(format: "%.2f km", distanceKm))
                Spacer()
                DetailStatCell(icon: "clock", label: "Duration", value: durationText)
                Spacer()
                DetailStatCell(icon: "speedometer", label: "Pace",
                               value: paceMinPerKm > 0 ? String(format: "%.1f min/km", paceMinPerKm) : "--")
            }

            Divider()

            HStack(spacing: 0) {
                DetailStatCell(icon: "hare", label: "Avg Speed",
                               value: String(format: "%.1f km/h", speedKmh))
                Spacer()
                DetailStatCell(icon: "location.fill", label: "Track Points",
                               value: "\(walk?.track.count ?? 0)")
                Spacer()
                DetailStatCell(icon: "mountain.2", label: "Elev. Gain",
                               value: elevationGain > 0 ? String(format: "%.0f m", elevationGain) : "--")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private func dogPhotosSection(dogIds: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dogs on this walk")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(dogIds, id: \.self) { dogId in
                        dogChip(for: dogId)
                    }
                }
            }
        }
    }

    /// Single dog avatar + name. Resolves the dogId against the
    /// view-model's hydrated dog map. Falls through to placeholder
    /// pawprint + truncated id only when the dog can't be loaded
    /// (deleted, archived, permission denied).
    @ViewBuilder
    private func dogChip(for dogId: String) -> some View {
        let dog = viewModel.selectedWalkDogs[dogId]
        let dogName = dog?.name ?? String(dogId.prefix(8))
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 52, height: 52)

                if let dog = dog {
                    UserAvatarView(
                        photoUrl: dog.photoUrl,
                        displayName: dog.name,
                        size: 52
                    )
                } else {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.secondary)
                }
            }
            Text(dogName)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showShareSheet = true
            } label: {
                Label("Share Walk", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func shareText(for walk: WalkHistory) -> String {
        let km = Double(walk.distanceMeters) / 1000.0
        let h = walk.durationSec / 3600
        let m = (walk.durationSec % 3600) / 60
        return """
        Check out my walk on WoofWalk!

        Distance: \(String(format: "%.2f km", km))
        Duration: \(h)h \(m)m
        Speed: \(String(format: "%.1f km/h", speedKmh))

        #WoofWalk #DogWalking
        """
    }
}

// MARK: - Detail Stat Cell

struct DetailStatCell: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text(value)
                .font(.callout.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }
}
