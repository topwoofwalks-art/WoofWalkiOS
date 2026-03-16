import SwiftUI

struct StreakBanner: View {
    let streak: WalkStreak

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak.currentStreak) Day Streak")
                    .font(.headline)

                if let daysToNext = streak.daysToNextMilestone {
                    Text("\(daysToNext) days to next milestone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if streak.freezesAvailable > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "snowflake")
                        .font(.caption)
                    Text("\(streak.freezesAvailable)")
                        .font(.caption.bold())
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.blue.opacity(0.1)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.1), Color.red.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}
