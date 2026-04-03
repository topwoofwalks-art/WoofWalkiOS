import SwiftUI

struct ProfileWalkHistorySection: View {
    let recentWalks: [RecentWalkDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Walks")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: WalkHistoryView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if recentWalks.isEmpty {
                // Placeholder data when no real walks are available
                ForEach(placeholderWalks, id: \.id) { walk in
                    walkHistoryMiniCard(
                        distance: walk.distance,
                        duration: walk.duration,
                        date: walk.date
                    )
                }
            } else {
                ForEach(recentWalks.prefix(3), id: \.id) { walk in
                    walkHistoryMiniCard(
                        distance: walk.distance,
                        duration: walk.duration,
                        date: walk.date
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func walkHistoryMiniCard(distance: String, duration: String, date: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 12) {
                    Label(distance, systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // Placeholder walk data for when no real walks exist
    private var placeholderWalks: [PlaceholderWalk] {
        [
            PlaceholderWalk(id: "1", distance: "2.3 km", duration: "35 min", date: "Today"),
            PlaceholderWalk(id: "2", distance: "1.8 km", duration: "28 min", date: "Yesterday"),
            PlaceholderWalk(id: "3", distance: "3.1 km", duration: "45 min", date: "Mar 15"),
        ]
    }
}

// MARK: - Placeholder Walk Model

private struct PlaceholderWalk: Identifiable {
    let id: String
    let distance: String
    let duration: String
    let date: String
}
