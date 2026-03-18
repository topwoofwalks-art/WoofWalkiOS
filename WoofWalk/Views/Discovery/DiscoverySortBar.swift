import SwiftUI

// MARK: - Discovery Sort Bar
// Shows result count and sort picker, matching the Android DiscoverScreen sort row.

struct DiscoverySortBar: View {
    let resultCount: Int
    @Binding var sortOption: DiscoverySortOption
    var onToggleView: (() -> Void)?
    var isMapView: Bool = false

    var body: some View {
        HStack {
            // Results count
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.turquoise60)
                Text("\(resultCount) provider\(resultCount == 1 ? "" : "s") found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sort menu
            Menu {
                ForEach(DiscoverySortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Image(systemName: iconForSortOption(option))
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
                        .fontWeight(.medium)
                }
                .foregroundColor(.turquoise60)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.turquoise60.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func iconForSortOption(_ option: DiscoverySortOption) -> String {
        switch option {
        case .distance: return "location"
        case .topRated: return "star.fill"
        case .priceLow: return "arrow.up"
        case .priceHigh: return "arrow.down"
        case .mostReviews: return "text.bubble"
        }
    }
}

// MARK: - Discovery Search Bar
// Reusable search bar component with map toggle and filter button.

struct DiscoverySearchBar: View {
    @Binding var searchText: String
    var isMapView: Bool = false
    var hasActiveFilters: Bool = false
    var onToggleMapView: (() -> Void)?
    var onFilterTapped: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search providers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )

            // Map/List toggle
            Button {
                onToggleMapView?()
            } label: {
                Image(systemName: isMapView ? "list.bullet" : "map")
                    .font(.title3)
                    .foregroundColor(.turquoise60)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(.systemGray6)))
            }

            // Filter button
            Button {
                onFilterTapped?()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: hasActiveFilters
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                    )
                    .font(.title3)
                    .foregroundColor(hasActiveFilters ? .turquoise60 : .secondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(.systemGray6)))

                    // Active indicator dot
                    if hasActiveFilters {
                        Circle()
                            .fill(Color.turquoise60)
                            .frame(width: 8, height: 8)
                            .offset(x: -2, y: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
