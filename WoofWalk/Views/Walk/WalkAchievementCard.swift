import SwiftUI

enum WalkAchievement: Identifiable {
    case perfectRoute       // 95%+ adherence
    case routeMaster        // 85%+ adherence
    case speedDemon         // 10%+ faster than average
    case explorer           // visited all POIs
    case precisionWalker    // <10m avg deviation

    var id: String {
        switch self {
        case .perfectRoute: return "perfectRoute"
        case .routeMaster: return "routeMaster"
        case .speedDemon: return "speedDemon"
        case .explorer: return "explorer"
        case .precisionWalker: return "precisionWalker"
        }
    }

    var icon: String {
        switch self {
        case .perfectRoute: return "star.circle.fill"
        case .routeMaster: return "map.circle.fill"
        case .speedDemon: return "bolt.circle.fill"
        case .explorer: return "binoculars.circle.fill"
        case .precisionWalker: return "scope"
        }
    }

    var color: Color {
        switch self {
        case .perfectRoute: return .yellow
        case .routeMaster: return .blue
        case .speedDemon: return .red
        case .explorer: return .green
        case .precisionWalker: return .purple
        }
    }

    var title: String {
        switch self {
        case .perfectRoute: return "Perfect Route"
        case .routeMaster: return "Route Master"
        case .speedDemon: return "Speed Demon"
        case .explorer: return "Explorer"
        case .precisionWalker: return "Precision Walker"
        }
    }

    var description: String {
        switch self {
        case .perfectRoute: return "95%+ route adherence"
        case .routeMaster: return "85%+ route adherence"
        case .speedDemon: return "10%+ faster than average"
        case .explorer: return "Visited all points of interest"
        case .precisionWalker: return "Under 10m average deviation"
        }
    }
}

struct WalkAchievementCard: View {
    let achievement: WalkAchievement
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(achievement.color)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.bold())
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(achievement.color.opacity(0.1))
        )
        .scaleEffect(isVisible ? 1.0 : 0.3)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
    }
}
