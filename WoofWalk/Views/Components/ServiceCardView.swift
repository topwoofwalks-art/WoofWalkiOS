import SwiftUI

// MARK: - Service Type

enum ServiceType: String, CaseIterable, Identifiable {
    case dailyWalks
    case inHomeSitting
    case daycare
    case overnightBoarding
    case grooming
    case training

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dailyWalks: return "Daily Walks"
        case .inHomeSitting: return "In-Home Sitting"
        case .daycare: return "Daycare"
        case .overnightBoarding: return "Overnight Boarding"
        case .grooming: return "Grooming"
        case .training: return "Training"
        }
    }

    var icon: String {
        switch self {
        case .dailyWalks: return "pawprint.fill"
        case .inHomeSitting: return "house.fill"
        case .daycare: return "calendar"
        case .overnightBoarding: return "house.lodge.fill"
        case .grooming: return "scissors"
        case .training: return "graduationcap.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .dailyWalks: return "Exercise and bathroom breaks"
        case .inHomeSitting: return "Care in your home"
        case .daycare: return "Daily care"
        case .overnightBoarding: return "Extended stays"
        case .grooming: return "Bathing and styling"
        case .training: return "Learn new tricks"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .dailyWalks: return Color(hex: 0x1E293B)
        case .inHomeSitting: return Color(hex: 0x3E2723)
        case .daycare: return Color(hex: 0x1A2332)
        case .overnightBoarding: return Color(hex: 0x1A2332)
        case .grooming: return Color(hex: 0x2A2318)
        case .training: return Color(hex: 0x1A2332)
        }
    }

    var iconColor: Color {
        switch self {
        case .dailyWalks: return .turquoise60
        case .inHomeSitting: return .orange60
        case .daycare: return .turquoise70
        case .overnightBoarding: return .orange70
        case .grooming: return .success60
        case .training: return .turquoise80
        }
    }

    var isLarge: Bool {
        switch self {
        case .dailyWalks, .inHomeSitting: return true
        default: return false
        }
    }

    static var largeTypes: [ServiceType] {
        allCases.filter { $0.isLarge }
    }

    static var smallTypes: [ServiceType] {
        allCases.filter { !$0.isLarge }
    }
}

// MARK: - Service Card Large

struct ServiceCardLarge: View {
    let serviceType: ServiceType
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(serviceType.iconColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: serviceType.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(serviceType.iconColor)
                }

                Spacer()

                Text(serviceType.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(serviceType.subtitle)
                    .font(.caption)
                    .foregroundColor(.neutral60)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(serviceType.backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Service Card Small

struct ServiceCardSmall: View {
    let serviceType: ServiceType
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(serviceType.iconColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: serviceType.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(serviceType.iconColor)
                }

                VStack(spacing: 2) {
                    Text(serviceType.name)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(serviceType.subtitle)
                        .font(.caption2)
                        .foregroundColor(.neutral60)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(serviceType.backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Service Cards Grid

struct ServiceCardsGrid: View {
    var onServiceTap: ((ServiceType) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            // Large service cards - 2 columns
            HStack(spacing: 12) {
                ForEach(ServiceType.largeTypes) { service in
                    ServiceCardLarge(serviceType: service) {
                        onServiceTap?(service)
                    }
                }
            }

            // Small service cards - 2x2 grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(ServiceType.smallTypes) { service in
                    ServiceCardSmall(serviceType: service) {
                        onServiceTap?(service)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Service Cards Grid") {
    ScrollView {
        ServiceCardsGrid { service in
            print("Tapped: \(service.name)")
        }
        .padding(16)
    }
    .background(Color.neutral10)
    .preferredColorScheme(.dark)
}

#Preview("Large Card") {
    HStack(spacing: 12) {
        ServiceCardLarge(serviceType: .dailyWalks)
        ServiceCardLarge(serviceType: .inHomeSitting)
    }
    .padding(16)
    .background(Color.neutral10)
    .preferredColorScheme(.dark)
}

#Preview("Small Card") {
    HStack(spacing: 12) {
        ServiceCardSmall(serviceType: .daycare)
        ServiceCardSmall(serviceType: .grooming)
    }
    .padding(16)
    .background(Color.neutral10)
    .preferredColorScheme(.dark)
}
