import SwiftUI
import MapKit

struct WalkHistoryScreen: View {
    @StateObject private var viewModel = WalkHistoryViewModel()
    @State private var searchText = ""
    @State private var sortOption: SortOption = .date

    enum SortOption: String, CaseIterable {
        case date = "Date"
        case distance = "Distance"
        case duration = "Duration"
    }

    // MARK: - Computed Properties

    private var sortedWalks: [WalkHistory] {
        var walks = viewModel.walks

        if !searchText.isEmpty {
            walks = walks.filter { walk in
                guard let date = walk.startedAt?.dateValue() else { return false }
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let dateStr = formatter.string(from: date)
                let dogStr = walk.dogIds.joined(separator: " ")
                return dateStr.localizedCaseInsensitiveContains(searchText)
                    || dogStr.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .date:
            walks.sort { ($0.startedAt?.dateValue() ?? .distantPast) > ($1.startedAt?.dateValue() ?? .distantPast) }
        case .distance:
            walks.sort { $0.distanceMeters > $1.distanceMeters }
        case .duration:
            walks.sort { $0.durationSec > $1.durationSec }
        }

        return walks
    }

    private var groupedByMonth: [(String, [WalkHistory])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let groups = Dictionary(grouping: sortedWalks) { walk -> String in
            guard let date = walk.startedAt?.dateValue() else { return "Unknown" }
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { return "Today" }
            if calendar.isDateInYesterday(date) { return "Yesterday" }
            if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
                return "This Week"
            }
            return formatter.string(from: date)
        }

        let priority = ["Today", "Yesterday", "This Week"]
        return groups.sorted { lhs, rhs in
            let li = priority.firstIndex(of: lhs.key) ?? Int.max
            let ri = priority.firstIndex(of: rhs.key) ?? Int.max
            if li != ri { return li < ri }
            return lhs.key > rhs.key // newer month names first
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.walks.isEmpty {
                ProgressView("Loading walks...")
            } else if viewModel.walks.isEmpty {
                emptyState
            } else {
                walkList
            }
        }
        .navigationTitle("Walk History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
        }
        .searchable(text: $searchText, prompt: "Search walks")
        .onAppear {
            viewModel.loadWalks()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "Unknown error")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "figure.walk")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No walks yet")
                .font(.title2.bold())
            Text("Start your first walk!")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var walkList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedByMonth, id: \.0) { section in
                    Section {
                        ForEach(section.1) { walk in
                            NavigationLink(value: AppRoute.walkHistoryDetail(walkId: walk.id ?? "")) {
                                WalkHistoryRow(walk: walk)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(section.0)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Label(option.rawValue, systemImage: sortIcon(for: option))
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }

    private func sortIcon(for option: SortOption) -> String {
        switch option {
        case .date: return "calendar"
        case .distance: return "point.topleft.down.to.point.bottomright.curvepath"
        case .duration: return "clock"
        }
    }
}

// MARK: - Walk History Row

struct WalkHistoryRow: View {
    let walk: WalkHistory

    private var formattedDate: String {
        guard let date = walk.startedAt?.dateValue() else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    private var distanceText: String {
        let km = Double(walk.distanceMeters) / 1000.0
        return String(format: "%.2f km", km)
    }

    private var durationText: String {
        let h = walk.durationSec / 3600
        let m = (walk.durationSec % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var paceText: String {
        guard walk.distanceMeters > 50, walk.durationSec > 0 else { return "--" }
        let kmh = (Double(walk.distanceMeters) / 1000.0) / (Double(walk.durationSec) / 3600.0)
        return String(format: "%.1f km/h", kmh)
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        walk.track.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Mini map thumbnail
            if !routeCoordinates.isEmpty {
                WalkMiniMap(coordinates: routeCoordinates)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "map")
                            .foregroundStyle(.tertiary)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    Label(distanceText, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    Label(durationText, systemImage: "clock")
                    Label(paceText, systemImage: "speedometer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !walk.dogIds.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "pawprint.fill")
                            .font(.caption2)
                        Text(walk.dogIds.prefix(3).joined(separator: ", "))
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Walk Mini Map

struct WalkMiniMap: View {
    let coordinates: [CLLocationCoordinate2D]

    var body: some View {
        Map(coordinateRegion: .constant(region))
            .overlay(
                WalkMapPolyline(coordinates: coordinates)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .disabled(true)
            .allowsHitTesting(false)
    }

    private var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2,
            longitude: ((lngs.min() ?? 0) + (lngs.max() ?? 0)) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: ((lats.max() ?? 0) - (lats.min() ?? 0)) * 1.4,
            longitudeDelta: ((lngs.max() ?? 0) - (lngs.min() ?? 0)) * 1.4
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
