import SwiftUI

struct ProfileWalkStreakCard: View {
    let user: UserProfile

    var body: some View {
        let streak = user.walkStreak ?? WalkStreak(currentStreak: 5, longestStreak: 14, freezesAvailable: 2)

        VStack(alignment: .leading, spacing: 12) {
            Text("Walk Streak")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\u{1F525}")
                        .font(.title2)
                    Text("\(streak.currentStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("\u{1F3C6}")
                        .font(.title2)
                    Text("\(streak.longestStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Best")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                if streak.freezesAvailable > 0 {
                    VStack(spacing: 4) {
                        Text("\u{2744}\u{FE0F}")
                            .font(.title2)
                        Text("\(streak.freezesAvailable)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Freezes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}
