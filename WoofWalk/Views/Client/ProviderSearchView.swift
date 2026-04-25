import SwiftUI
import CoreLocation

// MARK: - Provider Search View

struct ProviderSearchView: View {
    let serviceType: ServiceType
    @StateObject private var viewModel: ProviderSearchViewModel
    @State private var searchText = ""
    @State private var sortOption: DiscoverySortOption = .distance
    @State private var selectedProvider: ServiceProviderLite?
    @State private var showProviderDetail = false
    @State private var showBookingFlow = false
    @State private var bookingProviderId: String?
    @Environment(\.dismiss) private var dismiss

    init(serviceType: ServiceType) {
        self.serviceType = serviceType
        _viewModel = StateObject(wrappedValue: ProviderSearchViewModel(serviceType: serviceType))
    }

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
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Sort + count row
            sortRow

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView("Finding providers nearby...")
                Spacer()
            } else if filteredProviders.isEmpty {
                emptyState
            } else {
                providerList
            }
        }
        .navigationTitle(serviceType.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProviderDetail) {
            if let provider = selectedProvider {
                ProviderDetailSheet(
                    provider: provider,
                    reviews: viewModel.selectedProviderReviews,
                    isLoadingReviews: viewModel.isLoadingReviews,
                    onSelect: {
                        bookingProviderId = provider.id
                        showProviderDetail = false
                        showBookingFlow = true
                    }
                )
            }
        }
        .sheet(isPresented: $showBookingFlow) {
            NavigationStack {
                BookingFlowScreen(preselectedProviderId: bookingProviderId)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Sort Row

    private var sortRow: some View {
        HStack {
            Text("\(filteredProviders.count) provider\(filteredProviders.count == 1 ? "" : "s") within 25km")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Provider List

    private var providerList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredProviders) { provider in
                    Button {
                        selectedProvider = provider
                        viewModel.loadReviews(for: provider.id)
                        showProviderDetail = true
                    } label: {
                        ProviderSearchCard(provider: provider)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No providers found")
                .font(.headline)

            Text("No \(serviceType.name.lowercased()) providers were found within 25km of your location.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundColor(.turquoise60)
            }
            .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Provider Search Card

struct ProviderSearchCard: View {
    let provider: ServiceProviderLite

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                BusinessAvatarView(
                    photoUrl: provider.photoUrl,
                    isExternal: provider.isExternal,
                    size: 52
                )

                VStack(alignment: .leading, spacing: 4) {
                    // Name + verified badge
                    HStack(spacing: 4) {
                        Text(provider.name)
                            .font(.headline)
                            .lineLimit(1)

                        if provider.hasBackgroundCheck {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.turquoise60)
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
                        } else {
                            Text("New")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let price = provider.priceRange {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(price)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Service chips
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
                        Text(formatDistanceKm(dist))
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

    private func formatDistanceKm(_ km: Double) -> String {
        if km < 1 {
            return "\(Int(km * 1000))m"
        } else {
            return String(format: "%.1fkm", km)
        }
    }
}

// MARK: - Provider Detail Sheet

struct ProviderDetailSheet: View {
    let provider: ServiceProviderLite
    let reviews: [ProviderReview]
    let isLoadingReviews: Bool
    var onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Cover photo
                    coverPhoto

                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        headerSection
                            .padding(.top, 12)

                        // Badges
                        if provider.hasBackgroundCheck || provider.hasInsurance || provider.isPartner {
                            badgesRow
                        }

                        Divider()

                        // Bio / Experience
                        if provider.bio != nil || provider.experience != nil {
                            aboutSection
                            Divider()
                        }

                        // Service pricing
                        if !provider.servicePricing.isEmpty {
                            pricingSection
                            Divider()
                        }

                        // Reviews
                        reviewsSection

                        // Select button
                        selectButton
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Cover Photo

    private var coverPhoto: some View {
        ZStack(alignment: .bottomLeading) {
            let imageUrl = provider.heroPhotoUrl ?? provider.photoUrl
            if let urlStr = imageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(height: 220).clipped()
                    default:
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Name overlay
            HStack(alignment: .bottom, spacing: 12) {
                BusinessAvatarView(
                    photoUrl: provider.photoUrl,
                    isExternal: provider.isExternal,
                    size: 56
                )
                .overlay(Circle().stroke(Color.white, lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    if let firstService = provider.services.first {
                        Text(firstService)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }

                Spacer()
            }
            .padding(16)
        }
        .frame(height: 220)
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.turquoise60, Color.turquoise40],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 220)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let rating = provider.rating {
                    StarRatingView(rating: rating, size: 14)
                    Text(String(format: "%.1f", rating))
                        .font(.headline)
                    if let count = provider.reviewCount {
                        Text("(\(count) review\(count == 1 ? "" : "s"))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No reviews yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let price = provider.priceRange {
                HStack(spacing: 4) {
                    Image(systemName: "sterlingsign.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(price)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let dist = provider.distance {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(dist < 1 ? "\(Int(dist * 1000))m away" : String(format: "%.1fkm away", dist))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Badges

    private var badgesRow: some View {
        HStack(spacing: 12) {
            if provider.hasBackgroundCheck {
                badgeItem(icon: "checkmark.shield.fill", label: "Background\nChecked", color: .turquoise60)
            }
            if provider.hasInsurance {
                badgeItem(icon: "lock.shield.fill", label: "Fully\nInsured", color: .blue)
            }
            if provider.isPartner {
                badgeItem(icon: "star.circle.fill", label: "WoofWalk\nPartner", color: .orange60)
            }
        }
    }

    private func badgeItem(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)

            if let bio = provider.bio {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 20) {
                if let experience = provider.experience {
                    infoChip(icon: "briefcase", label: "Experience", value: experience)
                }
                if let responseTime = provider.responseTime {
                    infoChip(icon: "clock", label: "Response", value: responseTime)
                }
            }
        }
    }

    private func infoChip(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.turquoise60)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Services & Pricing")
                .font(.headline)

            ForEach(provider.servicePricing) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                        if let duration = item.duration {
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(CurrencyFormatter.shared.formatPrice(item.price, code: item.currencyCode))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.turquoise60)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
        }
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reviews")
                .font(.headline)

            if isLoadingReviews {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if reviews.isEmpty {
                Text("No reviews yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(reviews) { review in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle().fill(Color.neutral90).frame(width: 32, height: 32)
                                .overlay {
                                    if let url = review.authorPhotoUrl, let imgUrl = URL(string: url) {
                                        AsyncImage(url: imgUrl) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: { Color.clear }
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle")
                                            .foregroundColor(.secondary)
                                    }
                                }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(review.authorName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(review.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            StarRatingView(rating: review.rating, size: 10)
                        }

                        Text(review.text)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
    }

    // MARK: - Select Button

    private var selectButton: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Select Provider")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(provider.acceptingNewClients ? Color.turquoise60 : Color.neutral60)
            )
            .foregroundColor(.white)
        }
        .disabled(!provider.acceptingNewClients)
    }
}

// MARK: - View Model

@MainActor
class ProviderSearchViewModel: ObservableObject {
    @Published var providers: [ServiceProviderLite] = []
    @Published var isLoading = false
    @Published var selectedProviderReviews: [ProviderReview] = []
    @Published var isLoadingReviews = false

    private let serviceType: ServiceType
    private let repository = ProviderRepository()
    private let locationService = LocationService.shared

    private static let defaultLocation = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

    private var userLocation: CLLocationCoordinate2D {
        locationService.currentLocation ?? Self.defaultLocation
    }

    init(serviceType: ServiceType) {
        self.serviceType = serviceType
        load()
    }

    func load() {
        isLoading = true
        Task {
            do {
                providers = try await repository.searchProviders(
                    serviceType: serviceType.name,
                    location: userLocation,
                    radiusKm: 25
                )
            } catch {
                providers = []
            }
            isLoading = false
        }
    }

    func refresh() async {
        isLoading = true
        do {
            providers = try await repository.searchProviders(
                serviceType: serviceType.name,
                location: userLocation,
                radiusKm: 15
            )
        } catch {
            providers = []
        }
        isLoading = false
    }

    func loadReviews(for providerId: String) {
        isLoadingReviews = true
        selectedProviderReviews = []
        Task {
            selectedProviderReviews = (try? await repository.getProviderReviews(providerId: providerId)) ?? []
            isLoadingReviews = false
        }
    }
}
