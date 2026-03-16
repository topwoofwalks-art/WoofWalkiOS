import SwiftUI
import Charts

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var selectedTimeframe: TimeFrame = .allTime

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        ErrorView(message: error) {
                            Task {
                                await viewModel.loadStatistics()
                            }
                        }
                    } else {
                        timeframeSelector
                        overviewStatsCard
                        personalRecordsCard
                        weeklyChartCard
                        achievementsSection
                        contributionsCard
                    }
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .task {
                await viewModel.loadStatistics()
            }
        }
    }

    private var timeframeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                Button(action: {
                    selectedTimeframe = timeframe
                }) {
                    Text(timeframe.rawValue)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedTimeframe == timeframe ?
                            Color.accentColor : Color.gray.opacity(0.2)
                        )
                        .foregroundColor(
                            selectedTimeframe == timeframe ?
                            .white : .primary
                        )
                        .cornerRadius(20)
                }
            }
        }
    }

    private var overviewStatsCard: some View {
        VStack(spacing: 16) {
            Text("Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                StatColumn(
                    icon: "figure.walk",
                    label: "Total Walks",
                    value: "\(viewModel.totalWalks)"
                )
                StatColumn(
                    icon: "arrow.up.right",
                    label: "Distance",
                    value: viewModel.formatDistance(viewModel.totalDistance)
                )
            }

            Divider()

            HStack(spacing: 20) {
                StatColumn(
                    icon: "timer",
                    label: "Total Time",
                    value: viewModel.formatDuration(viewModel.totalTime)
                )
                StatColumn(
                    icon: "speedometer",
                    label: "Avg Speed",
                    value: viewModel.formatSpeed(viewModel.averageSpeed)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var personalRecordsCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                Text("Personal Records")
                    .font(.headline)
                Spacer()
            }

            RecordItem(
                label: "Longest Walk",
                value: viewModel.formatDistance(viewModel.personalRecords.longestWalkDistance),
                icon: "figure.walk.circle"
            )

            RecordItem(
                label: "Longest Time",
                value: viewModel.formatDuration(viewModel.personalRecords.longestWalkTime),
                icon: "clock.fill"
            )

            RecordItem(
                label: "Current Streak",
                value: "\(viewModel.currentStreak) days",
                icon: "flame.fill"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var weeklyChartCard: some View {
        VStack(spacing: 12) {
            Text("Weekly Activity")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(viewModel.weeklyWalkData.enumerated()), id: \.offset) { index, count in
                        BarMark(
                            x: .value("Day", dayLabel(for: index)),
                            y: .value("Walks", count)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(height: 200)
            } else {
                SimpleBarChart(data: viewModel.weeklyWalkData)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var achievementsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: AchievementsView(viewModel: viewModel)) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.achievements.prefix(5)) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private var contributionsCard: some View {
        VStack(spacing: 12) {
            Text("Contributions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 40) {
                ContributionStat(
                    icon: "mappin.and.ellipse",
                    label: "POIs Added",
                    value: "\(viewModel.contributions)"
                )
                ContributionStat(
                    icon: "camera.fill",
                    label: "Photos",
                    value: "0"
                )
                ContributionStat(
                    icon: "message.fill",
                    label: "Comments",
                    value: "0"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func dayLabel(for index: Int) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return days[index % 7]
    }
}

struct StatColumn: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecordItem: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct ContributionStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SimpleBarChart: View {
    let data: [Int]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: 32, height: CGFloat(value) * 10)

                    Text(dayLabel(for: index))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 200)
    }

    private func dayLabel(for index: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return days[index % 7]
    }
}

struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ?
                          Color.accentColor.opacity(0.2) :
                          Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(achievement.isUnlocked ?
                                   .accentColor : .gray)

                if !achievement.isUnlocked {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .trim(from: 0, to: achievement.progress)
                                .stroke(Color.accentColor, lineWidth: 2)
                                .rotationEffect(.degrees(-90))
                        )
                }
            }

            Text(achievement.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
    }
}

struct AchievementsView: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        List {
            ForEach(AchievementCategory.allCases, id: \.self) { category in
                Section(header: Text(category.rawValue.capitalized)) {
                    ForEach(viewModel.achievements.filter { $0.category == category }) { achievement in
                        AchievementRow(achievement: achievement)
                    }
                }
            }
        }
        .navigationTitle("Achievements")
    }
}

struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ?
                          Color.accentColor.opacity(0.2) :
                          Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: achievement.icon)
                    .foregroundColor(achievement.isUnlocked ?
                                   .accentColor : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.name)
                    .font(.headline)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !achievement.isUnlocked {
                    ProgressView(value: achievement.progress)
                        .tint(.accentColor)
                }
            }

            Spacer()

            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

enum TimeFrame: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case allTime = "All Time"
}

extension AchievementCategory: CaseIterable {
    static var allCases: [AchievementCategory] {
        return [.walks, .distance, .social, .special]
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}
