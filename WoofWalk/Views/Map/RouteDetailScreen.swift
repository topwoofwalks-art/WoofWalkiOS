import SwiftUI
import MapKit

struct RouteDetailScreen: View {
    let routeId: String
    @StateObject private var viewModel = RouteLibraryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showShareSheet = false

    private var route: WalkRoute? { viewModel.selectedRoute }

    // MARK: - Computed Properties

    private var distanceKm: Double {
        Double(route?.distanceMeters ?? 0) / 1000.0
    }

    private var durationText: String {
        let min = route?.walkTimeMin ?? 0
        let h = min / 60
        let m = min % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    private var elevGainText: String {
        let gain = route?.elevGainM ?? 0
        return gain > 0 ? "\(gain) m" : "--"
    }

    private var createdText: String {
        guard let date = route?.updatedAt?.dateValue() else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        route?.segments.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) } ?? []
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading && route == nil {
                    ProgressView("Loading route...")
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let route = route {
                    // Map with route polyline
                    if !routeCoordinates.isEmpty {
                        CompletionMapView(trackPoints: routeCoordinates)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                            .padding(.top, 8)
                    } else {
                        noMapPlaceholder
                    }

                    // Route name and summary
                    VStack(spacing: 6) {
                        Text(route.name.isEmpty ? "Untitled Route" : route.name)
                            .font(.title2.bold())

                        if !route.summary.isEmpty {
                            Text(route.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal)

                    // Tags
                    if !route.tags.isEmpty {
                        tagRow(tags: route.tags)
                            .padding(.top, 8)
                    }

                    // Stats
                    statsSection
                        .padding()

                    // Rating
                    if route.ratingCount > 0 {
                        ratingSection
                            .padding(.horizontal)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal)

                    // Footer
                    Text("Created on \(createdText)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Route not found")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
        }
        .navigationTitle("Route Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showShareSheet = true } label: {
                        Label("Share Route", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete Route", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Route", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteRoute(routeId: routeId)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this route? This cannot be undone.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let route = route {
                ShareSheet(activityItems: [shareText(for: route)])
            }
        }
        .onAppear {
            viewModel.selectRoute(routeId: routeId)
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
                    Text("No route preview")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            )
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private func tagRow(tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    private var statsSection: some View {
        HStack(spacing: 0) {
            DetailStatCell(icon: "point.topleft.down.to.point.bottomright.curvepath",
                           label: "Distance", value: String(format: "%.1f km", distanceKm))
            Spacer()
            DetailStatCell(icon: "clock", label: "Est. Duration", value: durationText)
            Spacer()
            DetailStatCell(icon: "mountain.2", label: "Elevation", value: elevGainText)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private var ratingSection: some View {
        HStack {
            HStack(spacing: 2) {
                ForEach(0..<5) { i in
                    Image(systemName: Double(i) < (route?.ratingAvg ?? 0) ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Text(String(format: "%.1f", route?.ratingAvg ?? 0))
                .font(.subheadline.weight(.medium))
            Text("(\(route?.ratingCount ?? 0) ratings)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                // Start walk with this route -- navigates to map
            } label: {
                Label("Start Walk", systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 10) {
                Button {
                    showShareSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button {
                    // Edit waypoints
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Helpers

    private func shareText(for route: WalkRoute) -> String {
        """
        Check out this route on WoofWalk!

        \(route.name)
        Distance: \(String(format: "%.1f km", distanceKm))
        Est. Duration: \(durationText)

        #WoofWalk #DogWalking
        """
    }
}
