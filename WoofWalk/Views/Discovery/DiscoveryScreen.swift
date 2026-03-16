import SwiftUI
import CoreLocation

struct DiscoveryScreen: View {
    @StateObject private var viewModel = DiscoveryViewModel()
    @State private var selectedType: DiscoveryServiceType = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Service type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DiscoveryServiceType.allCases, id: \.self) { type in
                            Button(action: { selectedType = type; viewModel.filter(type) }) {
                                Text(type.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(selectedType == type ? Color.turquoise60 : Color.neutral90))
                                    .foregroundColor(selectedType == type ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Results
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.providers) { provider in
                            ServiceProviderCard(provider: provider)
                        }

                        if viewModel.isLoading {
                            ProgressView().padding()
                        }

                        if viewModel.providers.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No providers found nearby")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Discover")
        }
    }
}

struct ServiceProviderCard: View {
    let provider: ServiceProviderLite

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Circle().fill(Color.neutral90).frame(width: 48, height: 48)
                    .overlay {
                        if let url = provider.photoUrl, let imgUrl = URL(string: url) {
                            AsyncImage(url: imgUrl) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "building.2").foregroundColor(.secondary)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(provider.name).font(.headline)
                        if provider.hasBackgroundCheck {
                            Image(systemName: "checkmark.seal.fill").font(.caption).foregroundColor(.turquoise60)
                        }
                    }

                    HStack(spacing: 4) {
                        if let rating = provider.rating {
                            Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating)).font(.caption)
                            if let count = provider.reviewCount { Text("(\(count))").font(.caption2).foregroundColor(.secondary) }
                        }
                        if let price = provider.priceRange {
                            Text("  \(price)").font(.caption).foregroundColor(.secondary)
                        }
                    }

                    // Services tags
                    HStack(spacing: 4) {
                        ForEach(provider.services.prefix(3), id: \.self) { service in
                            Text(service)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.turquoise90))
                                .foregroundColor(.turquoise30)
                        }
                    }
                }

                Spacer()

                if let dist = provider.distance {
                    Text(FormatUtils.formatDistance(dist * 1000))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !provider.acceptingNewClients {
                Text("Not accepting new clients")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }
}

@MainActor
class DiscoveryViewModel: ObservableObject {
    @Published var providers: [ServiceProviderLite] = []
    @Published var isLoading = false
    private let repository = DiscoveryRepository()
    private let locationService = LocationService.shared

    /// Default fallback coordinates (London) when user location is unavailable
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
}
