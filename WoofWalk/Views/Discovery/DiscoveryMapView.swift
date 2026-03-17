import SwiftUI
import MapKit

struct DiscoveryMapView: View {
    let providers: [ServiceProviderLite]
    @State private var selectedProvider: ServiceProviderLite?
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, selection: $selectedProvider) {
                UserAnnotation()

                ForEach(providers.filter { $0.latitude != nil && $0.longitude != nil }) { provider in
                    Annotation(
                        provider.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: provider.latitude!,
                            longitude: provider.longitude!
                        ),
                        anchor: .bottom
                    ) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedProvider = provider
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Image(systemName: iconForProvider(provider))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(colorForProvider(provider)))
                                    .shadow(radius: 2)

                                // Pin tail
                                Triangle()
                                    .fill(colorForProvider(provider))
                                    .frame(width: 10, height: 6)
                            }
                        }
                    }
                    .tag(provider)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // Selected provider card overlay
            if let provider = selectedProvider {
                selectedProviderCard(provider)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Selected Provider Card

    @ViewBuilder
    private func selectedProviderCard(_ provider: ServiceProviderLite) -> some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            HStack(spacing: 12) {
                // Avatar
                Circle().fill(Color.neutral90).frame(width: 48, height: 48)
                    .overlay {
                        if let url = provider.photoUrl, let imgUrl = URL(string: url) {
                            AsyncImage(url: imgUrl) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Color.clear }
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "building.2")
                                .foregroundColor(.secondary)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
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
                    HStack(spacing: 4) {
                        if let rating = provider.rating {
                            StarRatingView(rating: rating, size: 10)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                        }
                        if let price = provider.priceRange {
                            Text("· \(price)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    // Service tags
                    HStack(spacing: 4) {
                        ForEach(provider.services.prefix(2), id: \.self) { service in
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

                VStack(spacing: 8) {
                    if let dist = provider.distance {
                        Text(FormatUtils.formatDistance(dist * 1000))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(value: AppRoute.providerDetail(providerId: provider.id)) {
                        Text("Book Now")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.turquoise60))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onTapGesture {} // prevent map from stealing tap
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 50 {
                        withAnimation { selectedProvider = nil }
                    }
                }
        )
    }

    // MARK: - Helpers

    private func colorForProvider(_ provider: ServiceProviderLite) -> Color {
        guard let primaryService = provider.services.first?.lowercased() else { return .turquoise60 }
        switch primaryService {
        case "walking": return .turquoise60
        case "grooming": return .purple
        case "sitting": return .orange60
        case "boarding": return .blue
        case "daycare": return .yellow
        case "training": return .success60
        case "vet": return .red
        default: return .turquoise60
        }
    }

    private func iconForProvider(_ provider: ServiceProviderLite) -> String {
        guard let primaryService = provider.services.first?.lowercased() else { return "building.2" }
        switch primaryService {
        case "walking": return "figure.walk"
        case "grooming": return "scissors"
        case "sitting": return "house"
        case "boarding": return "bed.double"
        case "daycare": return "sun.max"
        case "training": return "graduationcap"
        case "vet": return "cross.case"
        default: return "building.2"
        }
    }
}

// MARK: - Pin Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

// Conform ServiceProviderLite to Hashable for Map selection
extension ServiceProviderLite: Hashable {
    static func == (lhs: ServiceProviderLite, rhs: ServiceProviderLite) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
