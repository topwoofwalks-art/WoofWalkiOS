import SwiftUI

struct PoiFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTypes: Set<PoiType>

    @State private var tempSelectedTypes: Set<PoiType>

    init(selectedTypes: Binding<Set<PoiType>>) {
        _selectedTypes = selectedTypes
        _tempSelectedTypes = State(initialValue: selectedTypes.wrappedValue)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select POI types to display on map")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    HStack(spacing: 8) {
                        Button("Special Places") {
                            tempSelectedTypes = [.park, .church, .landscape, .dogPark]
                        }
                        .buttonStyle(.bordered)

                        Button("Select All") {
                            tempSelectedTypes = Set(PoiType.allCases)
                        }
                        .buttonStyle(.bordered)

                        Button("Clear All") {
                            tempSelectedTypes = []
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Special Places to Visit")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.horizontal)

                        let specialPlaces: [PoiType] = [.park, .church, .landscape, .dogPark]
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(specialPlaces, id: \.self) { type in
                                PoiTypeFilterChip(
                                    type: type,
                                    isSelected: tempSelectedTypes.contains(type)
                                ) {
                                    toggleSelection(type)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Essential Amenities")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.horizontal)

                        let essentials: [PoiType] = [.bin, .water, .amenity]
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(essentials, id: \.self) { type in
                                PoiTypeFilterChip(
                                    type: type,
                                    isSelected: tempSelectedTypes.contains(type)
                                ) {
                                    toggleSelection(type)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Safety & Wildlife")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.horizontal)

                        let safety: [PoiType] = [.hazard, .livestock, .wildlife, .accessNote]
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(safety, id: \.self) { type in
                                PoiTypeFilterChip(
                                    type: type,
                                    isSelected: tempSelectedTypes.contains(type)
                                ) {
                                    toggleSelection(type)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        selectedTypes = tempSelectedTypes
                        dismiss()
                    } label: {
                        Text(tempSelectedTypes.isEmpty ? "Show All POIs" : "Apply Filter (\(tempSelectedTypes.count))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Filter POIs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggleSelection(_ type: PoiType) {
        if tempSelectedTypes.contains(type) {
            tempSelectedTypes.remove(type)
        } else {
            tempSelectedTypes.insert(type)
        }
    }
}

struct PoiTypeFilterChip: View {
    let type: PoiType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: type.iconName)
                    .font(.system(size: 16))
                Text(type.displayName)
                    .font(.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
}
