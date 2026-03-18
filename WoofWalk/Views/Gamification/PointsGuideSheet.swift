import SwiftUI

struct PointsGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("Points System Guide")
                            .font(.title2.bold())
                    }
                    .padding(.bottom, 4)

                    // Base Points
                    pointsSection(
                        title: "Earn Paw Points",
                        color: .turquoise60,
                        items: [
                            ("Complete a walk", "+10 points"),
                            ("Add a POI", "+5 points"),
                            ("Add a photo", "+3 points"),
                            ("Add a comment", "+2 points"),
                            ("Vote on POI", "+1 point"),
                            ("Verify POI", "+5 points")
                        ]
                    )

                    // Walk Distance Bonuses
                    pointsSection(
                        title: "Walk Bonuses",
                        color: .green,
                        items: [
                            ("Walk 1km+", "+5 bonus"),
                            ("Walk 3km+", "+15 bonus"),
                            ("Walk 5km+", "+30 bonus"),
                            ("Walk marathon (42km+)", "+100 bonus"),
                            ("Daily streak bonus", "+2 per day")
                        ]
                    )

                    Divider()

                    // Anti-Gaming Rules
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.red)
                            Text("Anti-Gaming Rules")
                                .font(.headline)
                                .foregroundColor(.red)
                        }

                        pointsSection(
                            title: "Violations & Penalties",
                            color: .red,
                            items: [
                                ("Walk < 100m", "No points"),
                                ("Duration < 2min", "No points"),
                                ("Speed > 8m/s (vehicle)", "-20 points"),
                                ("Suspicious GPS pattern", "-10 points"),
                                ("20+ walks per day", "-10 points"),
                                ("Too few GPS points", "No points")
                            ]
                        )
                    }

                    // Fair Play Notice
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fair Play Notice")
                                .font(.subheadline.bold())
                            Text("Our system validates walks using GPS data, speed analysis, and pattern detection. Gaming the system will result in point penalties and no rewards.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .padding()
            }
            .navigationTitle("Points Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func pointsSection(title: String, color: Color, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.primary)

            ForEach(items, id: \.0) { action, points in
                HStack {
                    Text(action)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(points)
                        .font(.subheadline.bold())
                        .foregroundColor(color)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}
