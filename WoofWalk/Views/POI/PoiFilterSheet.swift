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

                    quickSelectButtons
                    filterCategory(title: "Special Places to Visit", types: [.park, .church, .landscape, .dogPark])
                    filterCategory(title: "Essential Amenities", types: [.bin, .water, .amenity])
                    filterCategory(title: "Safety & Wildlife", types: [.hazard, .livestock, .wildlife, .accessNote])
                    applyButton
                }
            }
            .navigationTitle("Filter POIs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sub-views

    private var quickSelectButtons: some View {
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
    }

    private func filterCategory(title: String, types: [PoiType]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(types, id: \.self) { type in
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
    }

    private var applyButton: some View {
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
