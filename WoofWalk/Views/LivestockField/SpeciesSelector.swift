import SwiftUI

struct SpeciesSelector: View {
    @Binding var selectedSpecies: Set<LivestockSpecies>
    var showHazardToggle: Bool = true
    @State private var hazardousSpecies: Set<LivestockSpecies> = []

    private let allSpecies: [LivestockSpecies] = [.cattle, .sheep, .horse, .deer, .other]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(allSpecies, id: \.self) { species in
                    SpeciesButton(
                        species: species,
                        isSelected: selectedSpecies.contains(species),
                        isHazardous: hazardousSpecies.contains(species),
                        showHazard: showHazardToggle
                    ) {
                        toggleSpecies(species)
                    } onHazardToggle: {
                        toggleHazard(species)
                    }
                }
            }
        }
    }

    private func toggleSpecies(_ species: LivestockSpecies) {
        if selectedSpecies.contains(species) {
            selectedSpecies.remove(species)
            hazardousSpecies.remove(species)
        } else {
            selectedSpecies.insert(species)
        }
    }

    private func toggleHazard(_ species: LivestockSpecies) {
        if hazardousSpecies.contains(species) {
            hazardousSpecies.remove(species)
        } else {
            hazardousSpecies.insert(species)
        }
    }
}

struct SpeciesButton: View {
    let species: LivestockSpecies
    let isSelected: Bool
    let isHazardous: Bool
    let showHazard: Bool
    let onTap: () -> Void
    let onHazardToggle: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                            .frame(width: 60, height: 60)

                        if isHazardous {
                            Circle()
                                .stroke(Color.red, lineWidth: 3)
                                .frame(width: 60, height: 60)
                        }

                        Image(systemName: species.iconName)
                            .font(.system(size: 28))
                            .foregroundStyle(isSelected ? .white : .primary)
                    }

                    Text(species.displayName)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
            }

            if showHazard && isSelected {
                Button(action: onHazardToggle) {
                    HStack(spacing: 4) {
                        Image(systemName: isHazardous ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                            .font(.system(size: 10))
                        Text("Hazard")
                            .font(.caption2)
                    }
                    .foregroundStyle(isHazardous ? .red : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isHazardous ? Color.red.opacity(0.1) : Color(.systemGray6))
                    .cornerRadius(4)
                }
            }
        }
    }
}

extension LivestockSpecies {
    var iconName: String {
        switch self {
        case .cattle: return "figure.walk"
        case .sheep: return "cloud.fill"
        case .horse: return "hare.fill"
        case .deer: return "leaf.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}
