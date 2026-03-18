import SwiftUI

// MARK: - Compact Service Provider Card
// A smaller card variant for use in grid layouts or featured provider sections.
// Complements the full ServiceProviderCard in DiscoveryScreen.

struct ServiceProviderCardCompact: View {
    let provider: ServiceProviderLite

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hero/Photo area
            ZStack(alignment: .bottomLeading) {
                if let url = provider.heroPhotoUrl ?? provider.photoUrl,
                   let imgUrl = URL(string: url) {
                    AsyncImage(url: imgUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            photoPlaceholder
                        default:
                            photoPlaceholder
                                .overlay(ProgressView())
                        }
                    }
                    .frame(height: 120)
                    .clipped()
                } else {
                    photoPlaceholder
                }

                // Availability badge overlay
                if provider.availableNow {
                    Text("Available")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.success60))
                        .padding(8)
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info area
            VStack(alignment: .leading, spacing: 4) {
                // Name + verified badge
                HStack(spacing: 4) {
                    Text(provider.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    if provider.hasBackgroundCheck {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.turquoise60)
                    }
                }

                // Rating
                HStack(spacing: 4) {
                    if let rating = provider.rating {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
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

                    Spacer()

                    if let dist = provider.distance {
                        Text(FormatUtils.formatDistance(dist * 1000))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Service tags - compact
                HStack(spacing: 4) {
                    ForEach(provider.services.prefix(2), id: \.self) { service in
                        Text(service)
                            .font(.system(size: 9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.turquoise90))
                            .foregroundColor(.turquoise30)
                    }
                    if provider.services.count > 2 {
                        Text("+\(provider.services.count - 2)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
    }

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.turquoise90, Color(.systemGray5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 120)
            .overlay {
                Image(systemName: "building.2")
                    .font(.title2)
                    .foregroundColor(.secondary.opacity(0.5))
            }
    }
}

// MARK: - Featured Providers Section
// A horizontal scrolling section of featured/nearby providers.

struct FeaturedProvidersSection: View {
    let title: String
    let providers: [ServiceProviderLite]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("See All")
                    .font(.caption)
                    .foregroundColor(.turquoise60)
            }
            .padding(.horizontal, 16)

            if providers.isEmpty {
                Text("No providers found nearby")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(providers.prefix(8)) { provider in
                            NavigationLink(value: AppRoute.providerDetail(providerId: provider.id)) {
                                ServiceProviderCardCompact(provider: provider)
                                    .frame(width: 160)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Provider Quick Actions
// Action buttons shown at the bottom of a provider card or detail.

struct ProviderQuickActions: View {
    let provider: ServiceProviderLite
    var onBookTapped: (() -> Void)?
    var onMessageTapped: (() -> Void)?
    var onCallTapped: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if provider.phone != nil {
                quickActionButton(
                    icon: "phone.fill",
                    label: "Call",
                    color: .success60,
                    action: { onCallTapped?() }
                )
            }

            quickActionButton(
                icon: "message.fill",
                label: "Message",
                color: .turquoise60,
                action: { onMessageTapped?() }
            )

            quickActionButton(
                icon: "calendar.badge.plus",
                label: "Book",
                color: provider.acceptingNewClients ? .turquoise60 : .secondary,
                isPrimary: true,
                action: { onBookTapped?() }
            )
            .disabled(!provider.acceptingNewClients)
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.callout)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isPrimary ? .white : color)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPrimary ? color : color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
