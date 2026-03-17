import SwiftUI

struct ProviderDetailScreen: View {
    let providerId: String
    @StateObject private var viewModel: ProviderDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(providerId: String) {
        self.providerId = providerId
        _viewModel = StateObject(wrappedValue: ProviderDetailViewModel(providerId: providerId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading provider...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let provider = viewModel.provider {
                providerContent(provider)
            } else {
                errorState
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Provider Content

    private func providerContent(_ provider: ServiceProviderLite) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero photo
                heroSection(provider)

                VStack(alignment: .leading, spacing: 20) {
                    // Header: name, rating, price
                    headerSection(provider)

                    // Verification badges
                    if provider.hasBackgroundCheck || provider.hasInsurance || provider.isPartner {
                        badgesSection(provider)
                    }

                    Divider()

                    // Services & pricing
                    if !provider.servicePricing.isEmpty {
                        servicesSection(provider)
                        Divider()
                    }

                    // About
                    if provider.bio != nil || provider.experience != nil || provider.responseTime != nil {
                        aboutSection(provider)
                        Divider()
                    }

                    // Reviews
                    reviewsSection(provider)

                    // Contact buttons
                    if provider.phone != nil || provider.website != nil {
                        Divider()
                        contactSection(provider)
                    }

                    // Book Now
                    bookNowButton(provider)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero Section

    private func heroSection(_ provider: ServiceProviderLite) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            let imageUrl = provider.heroPhotoUrl ?? provider.photoUrl
            if let urlStr = imageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 260)
                            .clipped()
                    case .failure:
                        heroPlaceholder
                    default:
                        heroPlaceholder
                            .overlay(ProgressView())
                    }
                }
            } else {
                heroPlaceholder
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Overlay content
            HStack(alignment: .bottom, spacing: 12) {
                // Provider avatar
                Circle().fill(Color.white.opacity(0.2)).frame(width: 60, height: 60)
                    .overlay {
                        if let url = provider.photoUrl, let imgUrl = URL(string: url) {
                            AsyncImage(url: imgUrl) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Color.clear }
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "building.2.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )

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

                if provider.availableNow {
                    Text("Open Now")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.success60))
                }
            }
            .padding(16)
        }
        .frame(height: 260)
    }

    private var heroPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.turquoise60, Color.turquoise40],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 260)
    }

    // MARK: - Header Section

    private func headerSection(_ provider: ServiceProviderLite) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Rating row
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

            // Price range
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

            // Distance
            if let dist = provider.distance {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(FormatUtils.formatDistance(dist * 1000) + " away")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Badges Section

    private func badgesSection(_ provider: ServiceProviderLite) -> some View {
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

    // MARK: - Services Section

    private func servicesSection(_ provider: ServiceProviderLite) -> some View {
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
                    Text(item.price)
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

    // MARK: - About Section

    private func aboutSection(_ provider: ServiceProviderLite) -> some View {
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
                    infoItem(icon: "briefcase", label: "Experience", value: experience)
                }
                if let responseTime = provider.responseTime {
                    infoItem(icon: "clock", label: "Response", value: responseTime)
                }
            }
        }
    }

    private func infoItem(icon: String, label: String, value: String) -> some View {
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

    // MARK: - Reviews Section

    private func reviewsSection(_ provider: ServiceProviderLite) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reviews")
                    .font(.headline)
                Spacer()
                if let count = provider.reviewCount, count > 0 {
                    Text("See all \(count)")
                        .font(.caption)
                        .foregroundColor(.turquoise60)
                }
            }

            // Star summary bar
            if let rating = provider.rating {
                starSummaryBar(rating: rating, count: provider.reviewCount ?? 0)
            }

            // Individual reviews
            if viewModel.reviews.isEmpty {
                Text("No reviews yet. Be the first to leave a review!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.reviews.prefix(3)) { review in
                    reviewCard(review)
                }
            }
        }
    }

    private func starSummaryBar(rating: Double, count: Int) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", rating))
                    .font(.system(size: 36, weight: .bold))
                StarRatingView(rating: rating, size: 14)
                Text("\(count) review\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 3) {
                ForEach((1...5).reversed(), id: \.self) { star in
                    HStack(spacing: 4) {
                        Text("\(star)")
                            .font(.caption2)
                            .frame(width: 10)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.yellow)
                                    .frame(width: geo.size.width * barFraction(star: star, rating: rating), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func barFraction(star: Int, rating: Double) -> Double {
        // Simple approximation: the closer the average is to this star, the taller the bar
        let diff = abs(rating - Double(star))
        return max(0.05, 1.0 - (diff * 0.3))
    }

    private func reviewCard(_ review: ProviderReview) -> some View {
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

    // MARK: - Contact Section

    private func contactSection(_ provider: ServiceProviderLite) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact")
                .font(.headline)

            HStack(spacing: 16) {
                if let phone = provider.phone, let url = URL(string: "tel:\(phone)") {
                    Link(destination: url) {
                        contactButton(icon: "phone.fill", label: "Call", color: .success60)
                    }
                }

                NavigationLink(value: AppRoute.chatDetail(chatId: provider.id)) {
                    contactButton(icon: "message.fill", label: "Message", color: .turquoise60)
                }

                if let website = provider.website, let url = URL(string: website) {
                    Link(destination: url) {
                        contactButton(icon: "globe", label: "Website", color: .blue)
                    }
                }
            }
        }
    }

    private func contactButton(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Book Now Button

    private func bookNowButton(_ provider: ServiceProviderLite) -> some View {
        Button {
            // Book action handled by navigation or sheet
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text("Book Now")
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

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Could not load provider")
                .font(.headline)
            Button("Try Again") {
                viewModel.load()
            }
            .foregroundColor(.turquoise60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - View Model

@MainActor
class ProviderDetailViewModel: ObservableObject {
    @Published var provider: ServiceProviderLite?
    @Published var reviews: [ProviderReview] = []
    @Published var isLoading = false

    private let providerId: String
    private let repository = DiscoveryRepository()

    init(providerId: String) {
        self.providerId = providerId
        load()
    }

    func load() {
        isLoading = true
        Task {
            provider = try? await repository.getProviderDetails(id: providerId)
            reviews = (try? await repository.getProviderReviews(providerId: providerId)) ?? []
            isLoading = false
        }
    }
}
