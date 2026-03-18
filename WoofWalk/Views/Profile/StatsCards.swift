import SwiftUI

// MARK: - Streak Card

struct StreakCard: View {
    let dayStreak: Int
    let bestStreak: Int

    private let cardBackground = Color(red: 0.08, green: 0.18, blue: 0.2)
    private let streakOrange = Color(red: 1.0, green: 0.42, blue: 0.13)

    var body: some View {
        HStack(spacing: 0) {
            streakColumn(emoji: "\u{1F525}", value: dayStreak, label: "Day Streak")

            Divider()
                .frame(height: 48)
                .background(Color.white.opacity(0.15))

            streakColumn(emoji: "\u{1F3C6}", value: bestStreak, label: "Best Streak")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .cornerRadius(16)
    }

    private func streakColumn(emoji: String, value: Int, label: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(streakOrange)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weekly Goal Card

struct WeeklyGoalCard: View {
    let currentKm: Double
    let goalKm: Double
    let percentage: Int
    let walkCount: Int
    let duration: String
    let onEditGoal: () -> Void

    private let cardBackground = Color(red: 0.15, green: 0.15, blue: 0.17)
    private let progressColor = WoofWalkBranding.primaryColor
    private let trackColor = Color.white.opacity(0.1)

    private var progress: Double {
        min(Double(percentage) / 100.0, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("Weekly Goal")
                .font(.headline)
                .foregroundColor(.white)

            // Progress ring + stats row
            HStack(spacing: 20) {
                // Circular progress ring
                ZStack {
                    Circle()
                        .stroke(trackColor, lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Text("\(percentage)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: 72, height: 72)

                // Stats text
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f / %.1f km", currentKm, goalKm))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("This Week")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))

                    Text("\(walkCount) walks \u{2022} \(duration)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }

            // Linear progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(trackColor)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)

            // Edit Goal button
            HStack {
                Spacer()

                Button(action: onEditGoal) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.caption)
                        Text("Edit Goal")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(progressColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(progressColor.opacity(0.15))
                    .cornerRadius(20)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Previews

struct StatsCards_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                StreakCard(dayStreak: 2, bestStreak: 2)

                WeeklyGoalCard(
                    currentKm: 1.5,
                    goalKm: 10.0,
                    percentage: 15,
                    walkCount: 3,
                    duration: "28m",
                    onEditGoal: {}
                )
            }
            .padding()
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
