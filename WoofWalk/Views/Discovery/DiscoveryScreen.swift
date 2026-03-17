import SwiftUI
import CoreLocation

struct DiscoveryScreen: View {
    @StateObject private var viewModel = DiscoveryViewModel()
    @State private var selectedType: DiscoveryServiceType = .all
    @State private var searchText = ""
    @State private var showMapView = false
    @State private var sortOption: DiscoverySortOption = .distance
    @State private var showFilterSheet = false

    private var filteredProviders: [ServiceProviderLite] {
        var results = viewModel.providers

        // Text search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(query) ||
                $0.services.contains(where: { $0.lowercased().contains(query) }) ||
                ($0.bio?.lowercased().contains(query) ?? false)
            }
        }

        // Apply filters from the filter sheet
        if viewModel.filters.verifiedOnly {
            results = results.filter { $0.hasBackgroundCheck }
        }
        if viewModel.filters.availableNow {
            results = results.filter { $0.availableNow }
        }
        if viewModel.filters.minimumRating > 0 {
            results = results.filter { ($0.rating ?? 0) >= viewModel.filters.minimumRating }
        }
        if viewModel.filters.maxDistanceKm < 50 {
            results = results.filter { ($0.distance ?? 0) <= viewModel.filters.maxDistanceKm }
        }

        // Sort
        switch sortOption {
        case .distance:
            results.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
        case .topRated:
            results.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .priceLow:
            results.sort { ($0.priceRange ?? "zzz") < ($1.priceRange ?? "zzz") }
        case .priceHigh:
            results.sort { ($0.priceRange ?? "") > ($1.priceRange ?? "") }
        case .mostReviews:
            results.sort { ($0.reviewCount ?? 0) > ($1.reviewCount ?? 0) }
        }

        return results
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search providers...", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))

                    // Map/List toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showMapView.toggle() }
                    } label: {
                        Image(systemName: showMapView ? "list.bullet" : "map")
                            .font(.title3)
                            .foregroundColor(.turquoise60)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(.systemGray6)))
                    }

                    // Filter button
                    Button { showFilterSheet = true } label: {
                        Image(systemName: viewModel.filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(viewModel.filters.isActive ? .turquoise60 : .secondary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(.systemGray6)))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DiscoveryServiceType.allCases, id: \.self) { type in
                            Button(action: {
                                selectedType = type
                                viewModel.filter(type)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: iconForServiceType(type))
                                        .font(.caption2)
                                    Text(type.rawValue)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(selectedType == type ? Color.turquoise60 : Color.neutral90))
                                .foregroundColor(selectedType == type ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }

                // Sort picker + results count
                HStack {
                    Text("\(filteredProviders.count) provider\(filteredProviders.count == 1 ? "" : "s") found")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Menu {
                        ForEach(DiscoverySortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption2)
                            Text(sortOption.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(.turquoise60)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                // Content area
                if showMapView {
                    DiscoveryMapView(providers: filteredProviders)
                } else {
                    listContent
                }
            }
            .navigationTitle("Discover")
            .sheet(isPresented: $showFilterSheet) {
                AdvancedFilterSheet(filters: $viewModel.filters)
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredProviders) { provider in
                    NavigationLink(value: AppRoute.providerDetail(providerId: provider.id)) {
                        ServiceProviderCard(provider: provider)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }

                if filteredProviders.isEmpty && !viewModel.isLoading {
                    emptyState
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No providers found")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Try adjusting your filters or search terms")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text("Suggestions:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(["Walking", "Grooming", "Training"], id: \.self) { suggestion in
                        Button {
                            searchText = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.turquoise90))
                                .foregroundColor(.turquoise30)
                        }
                    }
                }
            }
            .padding(.top, 8)

            if viewModel.filters.isActive {
                Button {
                    viewModel.filters = DiscoveryFilters()
                } label: {
                    Label("Clear All Filters", systemImage: "xmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.turquoise60)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func iconForServiceType(_ type: DiscoveryServiceType) -> String {
        switch type {
        case .all: return "square.grid.2x2"
        case .walk: return "figure.walk"
        case .grooming: return "scissors"
        case .sitting: return "house"
        case .boarding: return "bed.double"
        case .daycare: return "sun.max"
        case .training: return "graduationcap"
        case .vet: return "cross.case"
        }
    }
}

// MARK: - Enhanced Service Provider Card

struct ServiceProviderCard: View {
    let provider: ServiceProviderLite

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Avatar
                Circle().fill(Color.neutral90).frame(width: 52, height: 52)
                    .overlay {
                        if let url = provider.photoUrl, let imgUrl = URL(string: url) {
                            AsyncImage(url: imgUrl) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.clear
                            }
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "building.2")
                                .foregroundColor(.secondary)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    // Name + badges
                    HStack(spacing: 4) {
                        Text(provider.name)
                            .font(.headline)
                            .lineLimit(1)

                        if provider.hasBackgroundCheck {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.turquoise60)
                        }
                        if provider.isPartner {
                            Image(systemName: "star.circle.fill")
                                .font(.caption)
                                .foregroundColor(.orange60)
                        }
                    }

                    // Rating row
                    HStack(spacing: 4) {
                        if let rating = provider.rating {
                            StarRatingView(rating: rating, size: 10)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .fontWeight(.medium)
                            if let count = provider.reviewCount {
                                Text("(\(count))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let price = provider.priceRange {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(price)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Service tags
                    HStack(spacing: 4) {
                        ForEach(provider.services.prefix(3), id: \.self) { service in
                            Text(service)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.turquoise90))
                                .foregroundColor(.turquoise30)
                        }
                        if provider.services.count > 3 {
                            Text("+\(provider.services.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Distance + availability
                VStack(alignment: .trailing, spacing: 4) {
                    if let dist = provider.distance {
                        Text(FormatUtils.formatDistance(dist * 1000))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if provider.availableNow {
                        Text("Available")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.success60)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !provider.acceptingNewClients {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption2)
                    Text("Not accepting new clients")
                        .font(.caption2)
                }
                .foregroundColor(.error60)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}

// MARK: - Star Rating View

struct StarRatingView: View {
    let rating: Double
    let size: CGFloat

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starName(for: index))
                    .font(.system(size: size))
                    .foregroundColor(.yellow)
            }
        }
    }

    private func starName(for index: Int) -> String {
        let threshold = Double(index)
        if rating >= threshold {
            return "star.fill"
        } else if rating >= threshold - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Discovery Filters

struct DiscoveryFilters {
    var maxDistanceKm: Double = 50
    var minimumRating: Double = 0
    var priceRanges: Set<String> = []
    var availableNow: Bool = false
    var verifiedOnly: Bool = false

    var isActive: Bool {
        maxDistanceKm < 50 || minimumRating > 0 || !priceRanges.isEmpty || availableNow || verifiedOnly
    }
}

// MARK: - View Model

@MainActor
class DiscoveryViewModel: ObservableObject {
    @Published var providers: [ServiceProviderLite] = []
    @Published var isLoading = false
    @Published var filters = DiscoveryFilters()
    private let repository = DiscoveryRepository()
    private let locationService = LocationService.shared

    private static let defaultLocation = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

    private var userLocation: CLLocationCoordinate2D {
        locationService.currentLocation ?? Self.defaultLocation
    }

    init() { load() }

    func load() {
        isLoading = true
        Task {
            providers = (try? await repository.searchProviders(near: userLocation)) ?? []
            isLoading = false
        }
    }

    func filter(_ type: DiscoveryServiceType) {
        isLoading = true
        Task {
            providers = (try? await repository.searchProviders(near: userLocation, serviceType: type.rawValue)) ?? []
            isLoading = false
        }
    }

    func refresh() async {
        isLoading = true
        providers = (try? await repository.searchProviders(near: userLocation)) ?? []
        isLoading = false
    }
}
