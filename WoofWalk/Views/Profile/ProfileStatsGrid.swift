import SwiftUI

struct ProfileStatsGrid: View {
    let data: ProfileData

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Walks",
                value: "\(data.totalWalks)",
                icon: "figure.walk",
                color: .blue
            )

            StatCard(
                title: "Distance",
                value: String(format: "%.1f km", Double(data.totalDistance) / 1000.0),
                icon: "map",
                color: .green
            )

            StatCard(
                title: "Time",
                value: "\(data.totalTime / 60)h",
                icon: "clock",
                color: .orange
            )

            StatCard(
                title: "Points",
                value: "\(data.user.pawPoints)",
                icon: "star.fill",
                color: .purple
            )

            StatCard(
                title: "Contributions",
                value: "\(data.contributions)",
                icon: "star",
                color: .pink
            )

            StatCard(
                title: "Badges",
                value: "\(data.user.badges.count)",
                icon: "rosette",
                color: .indigo
            )
        }
    }
}
