import SwiftUI
import Charts

struct ProfileStatsView: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if case .success(let data) = viewModel.uiState {
                        overviewStats(data: data)

                        weeklyActivityChart()

                        monthlyProgressSection()

                        achievementsSection()
                    } else {
                        ProgressView()
                            .padding(.top, 100)
                    }
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func overviewStats(data: ProfileData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatBox(
                    title: "Total Walks",
                    value: "\(data.totalWalks)",
                    icon: "figure.walk",
                    color: .blue
                )

                StatBox(
                    title: "Distance",
                    value: String(format: "%.1f km", Double(data.totalDistance) / 1000.0),
                    icon: "map",
                    color: .green
                )

                StatBox(
                    title: "Active Time",
                    value: formatTime(minutes: data.totalTime),
                    icon: "clock",
                    color: .orange
                )

                StatBox(
                    title: "Avg Distance",
                    value: data.totalWalks > 0 ?
                        String(format: "%.1f km", Double(data.totalDistance) / Double(data.totalWalks) / 1000.0) :
                        "0 km",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func weeklyActivityChart() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.headline)

            Chart {
                ForEach(0..<7, id: \.self) { index in
                    BarMark(
                        x: .value("Day", dayName(index: index)),
                        y: .value("Walks", viewModel.weeklyWalkData[index])
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func monthlyProgressSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Progress")
                .font(.headline)

            VStack(spacing: 8) {
                ProgressBar(
                    title: "Distance Goal",
                    current: 25.3,
                    target: 50.0,
                    unit: "km",
                    color: .green
                )

                ProgressBar(
                    title: "Walk Count Goal",
                    current: 12,
                    target: 20,
                    unit: "walks",
                    color: .blue
                )

                ProgressBar(
                    title: "Active Days",
                    current: 8,
                    target: 15,
                    unit: "days",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func achievementsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Achievements")
                .font(.headline)

            VStack(spacing: 8) {
                ProfileAchievementRow(
                    icon: "trophy.fill",
                    title: "10 Walks Completed",
                    date: "2 days ago",
                    color: .yellow
                )

                ProfileAchievementRow(
                    icon: "flame.fill",
                    title: "5 Day Streak",
                    date: "Yesterday",
                    color: .orange
                )

                ProfileAchievementRow(
                    icon: "map.fill",
                    title: "5km Distance Milestone",
                    date: "Last week",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func dayName(index: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][index]
    }

    private func formatTime(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProgressBar: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    private var progress: Double {
        min(current / target, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProfileAchievementRow: View {
    let icon: String
    let title: String
    let date: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProfileStatsView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileStatsView()
    }
}
