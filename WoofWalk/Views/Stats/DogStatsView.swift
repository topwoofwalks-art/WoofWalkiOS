#if false
// Disabled: depends on StatsViewModel which is #if false
import SwiftUI
import Charts

struct DogStatsView: View {
    let dogId: String
    let dogName: String
    @StateObject private var viewModel = StatsViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    totalStatsCard
                    periodSelector
                    periodStatsContent
                }
            }
            .padding()
        }
        .navigationTitle("\(dogName)'s Stats")
        .task {
            await viewModel.loadStatistics()
        }
    }

    private var totalStatsCard: some View {
        VStack(spacing: 16) {
            Text("Total Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                DogStatItem(
                    icon: "figure.walk",
                    label: "Walks",
                    value: "\(viewModel.walksPerDog[dogId] ?? 0)"
                )
                DogStatItem(
                    icon: "speedometer",
                    label: "Distance",
                    value: viewModel.formatDistance(viewModel.distancePerDog[dogId] ?? 0)
                )
                DogStatItem(
                    icon: "timer",
                    label: "Time",
                    value: viewModel.formatDuration(viewModel.totalTime)
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private var periodSelector: some View {
        Picker("Period", selection: $selectedTab) {
            Text("Weekly").tag(0)
            Text("Monthly").tag(1)
        }
        .pickerStyle(SegmentedPickerStyle())
    }

    private var periodStatsContent: some View {
        Group {
            if selectedTab == 0 {
                weeklyStatsView
            } else {
                monthlyStatsView
            }
        }
    }

    private var weeklyStatsView: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.weeklyStats) { stat in
                PeriodStatsCard(stat: stat, viewModel: viewModel)
            }
        }
    }

    private var monthlyStatsView: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.monthlyStats) { stat in
                PeriodStatsCard(stat: stat, viewModel: viewModel)
            }
        }
    }
}

struct DogStatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }
}

struct PeriodStatsCard: View {
    let stat: PeriodStats
    let viewModel: StatsViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text(stat.period)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 16) {
                StatRow(
                    icon: "figure.walk",
                    label: "Walks",
                    value: "\(stat.walkCount)"
                )
            }

            HStack(spacing: 16) {
                StatRow(
                    icon: "arrow.up.right",
                    label: "Distance",
                    value: viewModel.formatDistance(stat.distanceMeters)
                )
            }

            HStack(spacing: 16) {
                StatRow(
                    icon: "timer",
                    label: "Duration",
                    value: viewModel.formatDuration(stat.durationSec)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct DogStatsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DogStatsView(dogId: "test-id", dogName: "Max")
        }
    }
}
#endif
