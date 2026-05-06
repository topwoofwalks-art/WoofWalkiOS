import SwiftUI

// MARK: - Services Category Grid
// Matches Android's ServicesScreen - a directory of service categories
// with featured alert cards and navigation to category-filtered discovery.

struct ServicesCategoryGrid: View {
    var onSelectCategory: ((DiscoveryServiceType) -> Void)?
    var onLostDogTapped: (() -> Void)?
    var onInviteWalkerTapped: (() -> Void)?
    var onEmergencyVetTapped: (() -> Void)?
    // Marketplace removed (Android task #74); the corresponding row is gone.

    var body: some View {
        VStack(spacing: 16) {
            // Lost Dog Alert - prominent red card
            LostDogAlertCard(onTap: onLostDogTapped)

            // Invite Walker - green CTA card
            InviteWalkerCard(onTap: onInviteWalkerTapped)

            // Section: Dog Care Services
            VStack(alignment: .leading, spacing: 12) {
                Text("Dog Care Services")
                    .font(.title3.bold())
                    .padding(.top, 4)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ServiceCategoryTile(
                        title: "Dog Walking",
                        subtitle: "Find walkers nearby",
                        icon: "figure.walk",
                        color: .turquoise60
                    ) {
                        onSelectCategory?(.walk)
                    }

                    ServiceCategoryTile(
                        title: "Grooming",
                        subtitle: "Professional groomers",
                        icon: "scissors",
                        color: .purple
                    ) {
                        onSelectCategory?(.grooming)
                    }

                    ServiceCategoryTile(
                        title: "Dog Sitting",
                        subtitle: "In-home pet care",
                        icon: "house",
                        color: .orange
                    ) {
                        onSelectCategory?(.sitting)
                    }

                    ServiceCategoryTile(
                        title: "Boarding",
                        subtitle: "Overnight stays",
                        icon: "bed.double",
                        color: .blue
                    ) {
                        onSelectCategory?(.boarding)
                    }

                    ServiceCategoryTile(
                        title: "Training",
                        subtitle: "Professional trainers",
                        icon: "graduationcap",
                        color: .green
                    ) {
                        onSelectCategory?(.training)
                    }

                    ServiceCategoryTile(
                        title: "Daycare",
                        subtitle: "Daytime dog care",
                        icon: "sun.max",
                        color: .yellow
                    ) {
                        onSelectCategory?(.daycare)
                    }
                }
            }

            // Section: More
            VStack(alignment: .leading, spacing: 12) {
                Text("More")
                    .font(.title3.bold())
                    .padding(.top, 4)

                ServiceCategoryRow(
                    title: "Emergency Vet",
                    subtitle: "Find the nearest emergency vet",
                    icon: "cross.case.fill",
                    iconColor: .red
                ) {
                    onEmergencyVetTapped?()
                }

                ServiceCategoryRow(
                    title: "Vet Services",
                    subtitle: "Find vets near you",
                    icon: "cross.case",
                    iconColor: .red
                ) {
                    onSelectCategory?(.vet)
                }
            }
        }
    }
}

// MARK: - Lost Dog Alert Card

struct LostDogAlertCard: View {
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Lost Dog Alert")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Report or find missing dogs nearby")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.34, blue: 0.13), Color(red: 0.83, green: 0.18, blue: 0.18)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Invite Walker Card

struct InviteWalkerCard: View {
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 32))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Invite your trusted puppy care team")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Get GPS tracking, photos & easy payments")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.30, green: 0.69, blue: 0.31), Color(red: 0.18, green: 0.49, blue: 0.20)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Service Category Tile (Grid)

struct ServiceCategoryTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(color.opacity(0.12))
                    )

                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Service Category Row (List)

struct ServiceCategoryRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
