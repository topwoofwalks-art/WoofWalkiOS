import SwiftUI
import MapKit

struct DiscoveryMapView: View {
    let providers: [ServiceProviderLite]
    @State private var selectedProvider: ServiceProviderLite?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private var mappableProviders: [ServiceProviderLite] {
        providers.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: mappableProviders) { provider in
                MapAnnotation(coordinate: CLLocationCoordinate2D(
                    latitude: provider.latitude!,
                    longitude: provider.longitude!
                )) {
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

                            Triangle()
                                .fill(colorForProvider(provider))
                                .frame(width: 10, height: 6)
                        }
                    }
                }
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
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            HStack(spacing: 12) {
                Circle().fill(Color.gray.opacity(0.2)).frame(width: 48, height: 48)
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
                                .foregroundColor(.blue)
                        }
                    }
                    HStack(spacing: 4) {
                        if let rating = provider.rating {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                        }
                        if let price = provider.priceRange {
                            Text("· \(price)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(provider.services.prefix(2), id: \.self) { service in
                            Text(service)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.1)))
                                .foregroundColor(.blue)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    if let dist = provider.distance {
                        Text(String(format: "%.1fkm", dist))
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
                            .background(Capsule().fill(Color.blue))
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
        guard let primaryService = provider.services.first?.lowercased() else { return .blue }
        switch primaryService {
        case "walking": return .blue
        case "grooming": return .purple
        case "sitting": return .orange
        case "boarding": return .blue
        case "daycare": return .yellow
        case "training": return .green
        case "vet": return .red
        default: return .blue
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
