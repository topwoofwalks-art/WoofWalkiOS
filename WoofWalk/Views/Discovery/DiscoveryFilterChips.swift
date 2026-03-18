import SwiftUI

// MARK: - Discovery Filter Chips
// Reusable horizontal scrolling filter chip bar for the Discovery screen.
// Matches the Android FilterChip row with icons and selected state styling.

struct DiscoveryFilterChips: View {
    @Binding var selectedType: DiscoveryServiceType
    var onSelect: ((DiscoveryServiceType) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscoveryServiceType.allCases, id: \.self) { type in
                    DiscoveryFilterChip(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                        onSelect?(type)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Individual Filter Chip

struct DiscoveryFilterChip: View {
    let type: DiscoveryServiceType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.caption2)
                Text(type.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.turquoise60 : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var iconName: String {
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

// MARK: - Active Filters Summary Bar
// Shows applied filter count and quick clear button.

struct ActiveFiltersSummaryBar: View {
    let filters: DiscoveryFilters
    var onClearAll: (() -> Void)?

    private var activeCount: Int {
        var count = 0
        if filters.maxDistanceKm < 50 { count += 1 }
        if filters.minimumRating > 0 { count += 1 }
        if !filters.priceRanges.isEmpty { count += 1 }
        if filters.availableNow { count += 1 }
        if filters.verifiedOnly { count += 1 }
        return count
    }

    var body: some View {
        if filters.isActive {
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if filters.maxDistanceKm < 50 {
                            ActiveFilterTag(
                                label: "\(Int(filters.maxDistanceKm))km",
                                icon: "location"
                            )
                        }
                        if filters.minimumRating > 0 {
                            ActiveFilterTag(
                                label: "\(Int(filters.minimumRating))+ stars",
                                icon: "star.fill"
                            )
                        }
                        if !filters.priceRanges.isEmpty {
                            ActiveFilterTag(
                                label: filters.priceRanges.sorted().joined(separator: ", "),
                                icon: "sterlingsign.circle"
                            )
                        }
                        if filters.availableNow {
                            ActiveFilterTag(
                                label: "Available Now",
                                icon: "clock.badge.checkmark"
                            )
                        }
                        if filters.verifiedOnly {
                            ActiveFilterTag(
                                label: "Verified",
                                icon: "checkmark.seal.fill"
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Button {
                    onClearAll?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                        Text("Clear")
                            .font(.caption)
                    }
                    .foregroundColor(.turquoise60)
                    .padding(.trailing, 16)
                }
            }
            .padding(.vertical, 6)
            .background(Color(.systemGray6).opacity(0.6))
        }
    }
}

// MARK: - Active Filter Tag

struct ActiveFilterTag: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.turquoise60.opacity(0.12))
        )
        .foregroundColor(.turquoise60)
    }
}
