import SwiftUI

struct MilestonesListScreen: View {
    private let milestones = MilestoneRepository.allMilestones

    private var grouped: [MilestoneType: [DogMilestone]] {
        Dictionary(grouping: milestones, by: \.type)
    }

    private let sectionOrder: [MilestoneType] = [.walkCount, .distance, .streak, .timeTogether, .funDistance]

    var body: some View {
        List {
            ForEach(sectionOrder, id: \.self) { type in
                if let items = grouped[type], !items.isEmpty {
                    Section(header: sectionHeader(for: type)) {
                        ForEach(items) { milestone in
                            milestoneRow(milestone)
                        }
                    }
                }
            }
        }
        .navigationTitle("Milestones")
    }

    // MARK: - Section Header

    private func sectionHeader(for type: MilestoneType) -> some View {
        HStack(spacing: 6) {
            Image(systemName: iconName(for: type))
                .foregroundColor(iconColor(for: type))
            Text(displayName(for: type))
        }
    }

    private func iconName(for type: MilestoneType) -> String {
        switch type {
        case .walkCount: return "figure.walk"
        case .distance: return "map.fill"
        case .streak: return "flame.fill"
        case .timeTogether: return "clock.fill"
        case .funDistance: return "globe.europe.africa.fill"
        }
    }

    private func iconColor(for type: MilestoneType) -> Color {
        switch type {
        case .walkCount: return .blue
        case .distance: return .green
        case .streak: return .orange
        case .timeTogether: return .purple
        case .funDistance: return .teal
        }
    }

    private func displayName(for type: MilestoneType) -> String {
        switch type {
        case .walkCount: return "Walk Count"
        case .distance: return "Distance"
        case .streak: return "Streak"
        case .timeTogether: return "Time Together"
        case .funDistance: return "Fun Distance"
        }
    }

    // MARK: - Row

    private func milestoneRow(_ milestone: DogMilestone) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundColor(.yellow)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.headline)
                Text(milestone.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 2) {
                Image(systemName: "pawprint.fill")
                    .font(.caption2)
                Text("+\(milestone.pawPointsBonus)")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
}
