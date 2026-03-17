import SwiftUI

struct AdvancedFilterSheet: View {
    @Binding var filters: DiscoveryFilters
    @Environment(\.dismiss) private var dismiss

    // Local state for editing (only applied on "Apply")
    @State private var localFilters: DiscoveryFilters

    init(filters: Binding<DiscoveryFilters>) {
        _filters = filters
        _localFilters = State(initialValue: filters.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Distance
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Maximum Distance")
                            Spacer()
                            Text("\(Int(localFilters.maxDistanceKm)) km")
                                .foregroundColor(.turquoise60)
                                .fontWeight(.medium)
                        }
                        Slider(value: $localFilters.maxDistanceKm, in: 1...50, step: 1)
                            .tint(.turquoise60)
                    }
                } header: {
                    Label("Distance", systemImage: "location")
                }

                // Minimum rating
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Rating")
                            Spacer()
                            if localFilters.minimumRating > 0 {
                                Text(String(format: "%.0f+", localFilters.minimumRating))
                                    .foregroundColor(.turquoise60)
                                    .fontWeight(.medium)
                            } else {
                                Text("Any")
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 8) {
                            ForEach(0...5, id: \.self) { star in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        localFilters.minimumRating = Double(star)
                                    }
                                } label: {
                                    if star == 0 {
                                        Text("Any")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(localFilters.minimumRating == 0 ? Color.turquoise60 : Color(.systemGray5))
                                            )
                                            .foregroundColor(localFilters.minimumRating == 0 ? .white : .primary)
                                    } else {
                                        HStack(spacing: 2) {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                            Text("\(star)")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(localFilters.minimumRating == Double(star) ? Color.turquoise60 : Color(.systemGray5))
                                        )
                                        .foregroundColor(localFilters.minimumRating == Double(star) ? .white : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Label("Rating", systemImage: "star")
                }

                // Price range
                Section {
                    ForEach(["$", "$$", "$$$"], id: \.self) { price in
                        Button {
                            if localFilters.priceRanges.contains(price) {
                                localFilters.priceRanges.remove(price)
                            } else {
                                localFilters.priceRanges.insert(price)
                            }
                        } label: {
                            HStack {
                                Text(priceLabel(price))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: localFilters.priceRanges.contains(price) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(localFilters.priceRanges.contains(price) ? .turquoise60 : .secondary)
                            }
                        }
                    }
                } header: {
                    Label("Price Range", systemImage: "sterlingsign.circle")
                }

                // Toggles
                Section {
                    Toggle(isOn: $localFilters.availableNow) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundColor(.success60)
                            Text("Available Now")
                        }
                    }
                    .tint(.turquoise60)

                    Toggle(isOn: $localFilters.verifiedOnly) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.turquoise60)
                            Text("Verified Only")
                        }
                    }
                    .tint(.turquoise60)
                } header: {
                    Label("Availability & Trust", systemImage: "shield")
                }

                // Active filter summary
                if localFilters.isActive {
                    Section {
                        HStack {
                            Text("Active filters: \(activeFilterCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        withAnimation { localFilters = DiscoveryFilters() }
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        filters = localFilters
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.turquoise60)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func priceLabel(_ price: String) -> String {
        switch price {
        case "$": return "Budget-friendly"
        case "$$": return "Mid-range"
        case "$$$": return "Premium"
        default: return price
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if localFilters.maxDistanceKm < 50 { count += 1 }
        if localFilters.minimumRating > 0 { count += 1 }
        if !localFilters.priceRanges.isEmpty { count += 1 }
        if localFilters.availableNow { count += 1 }
        if localFilters.verifiedOnly { count += 1 }
        return count
    }
}
