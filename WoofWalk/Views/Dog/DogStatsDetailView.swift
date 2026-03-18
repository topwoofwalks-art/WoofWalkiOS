import SwiftUI

struct DogStatsDetailView: View {
    let dogId: String
    let dogName: String
    @State private var selectedPeriod: StatsPeriod = .allTime
    @StateObject private var viewModel = DogStatsDetailViewModel()

    enum StatsPeriod: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case allTime = "All Time"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Period picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatsPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Stats cards grid (2x3)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "Walks",
                        value: "\(viewModel.totalWalks)",
                        icon: "figure.walk",
                        color: .blue
                    )
                    StatCard(
                        title: "Distance",
                        value: viewModel.formattedDistance,
                        icon: "map",
                        color: .green
                    )
                    StatCard(
                        title: "Duration",
                        value: viewModel.formattedDuration,
                        icon: "clock",
                        color: .orange
                    )
                    StatCard(
                        title: "Avg Pace",
                        value: viewModel.formattedAvgPace,
                        icon: "speedometer",
                        color: .purple
                    )
                    StatCard(
                        title: "Longest Walk",
                        value: viewModel.formattedLongestWalk,
                        icon: "arrow.up.right",
                        color: .red
                    )
                    StatCard(
                        title: "Streak",
                        value: "\(viewModel.currentStreak) days",
                        icon: "flame",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // Birthday countdown section
                if let birthdate = viewModel.birthdateString {
                    BirthdayCountdown(birthdateString: birthdate, dogName: dogName)
                        .padding(.horizontal)
                }

                // Milestones section
                if !viewModel.milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Milestones")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.milestones) { milestone in
                            let achieved = viewModel.achievedMilestoneIds.contains(milestone.id)
                            HStack {
                                Image(systemName: achieved ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(achieved ? .green : .secondary)
                                Text(milestone.title)
                                    .font(.subheadline)
                                Spacer()
                                Text("+\(milestone.pawPointsBonus)")
                                    .font(.caption)
                                    .foregroundColor(achieved ? .turquoise60 : .secondary)
                            }
                            .opacity(achieved ? 1.0 : 0.5)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 1)
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .navigationTitle("\(dogName) Stats")
        .task {
            await viewModel.load(dogId: dogId)
        }
        .onChange(of: selectedPeriod) { _ in
            Task {
                await viewModel.load(dogId: dogId, period: selectedPeriod)
            }
        }
    }
}

@MainActor
class DogStatsDetailViewModel: ObservableObject {
    @Published var totalWalks: Int = 0
    @Published var totalDistanceMeters: Int64 = 0
    @Published var totalDurationMinutes: Int = 0
    @Published var avgPaceMinPerKm: Double? = nil
    @Published var longestWalkMeters: Int64? = nil
    @Published var currentStreak: Int = 0
    @Published var birthdateString: String? = nil
    @Published var milestones: [DogMilestone] = []
    @Published var achievedMilestoneIds: Set<String> = []

    private let repository = MilestoneRepository()

    var formattedDistance: String {
        FormatUtils.formatDistance(Double(Int(totalDistanceMeters)))
    }

    var formattedDuration: String {
        if totalDurationMinutes >= 60 {
            let hours = totalDurationMinutes / 60
            let mins = totalDurationMinutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(totalDurationMinutes)m"
    }

    var formattedAvgPace: String {
        guard let pace = avgPaceMinPerKm else { return "\u{2014}" }
        return String(format: "%.1f min/km", pace)
    }

    var formattedLongestWalk: String {
        guard let meters = longestWalkMeters else { return "\u{2014}" }
        return FormatUtils.formatDistance(Double(Int(meters)))
    }

    func load(dogId: String, period: DogStatsDetailView.StatsPeriod = .allTime) async {
        if let stats = try? await repository.getDogWalkStats(dogId: dogId) {
            totalWalks = stats.totalWalks
            totalDistanceMeters = stats.totalDistanceMeters
            currentStreak = stats.currentStreak
            achievedMilestoneIds = Set(stats.achievedMilestones)
        }
        milestones = MilestoneRepository.allMilestones
    }
}
