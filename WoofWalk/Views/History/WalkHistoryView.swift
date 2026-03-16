import SwiftUI

struct WalkHistoryView: View {
    @StateObject private var viewModel = WalkHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var sortOption: SortOption = .date
    @State private var filterOption: FilterOption = .all

    enum SortOption: String, CaseIterable {
        case date = "Date"
        case distance = "Distance"
        case duration = "Duration"
    }

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }

    private var filteredWalks: [WalkHistory] {
        var walks = viewModel.walks

        if !searchText.isEmpty {
            walks = walks.filter { walk in
                guard let date = walk.startedAt?.dateValue() else { return false }
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date).localizedCaseInsensitiveContains(searchText)
            }
        }

        let now = Date()
        switch filterOption {
        case .all:
            break
        case .today:
            walks = walks.filter { walk in
                guard let date = walk.startedAt?.dateValue() else { return false }
                return Calendar.current.isDateInToday(date)
            }
        case .week:
            walks = walks.filter { walk in
                guard let date = walk.startedAt?.dateValue() else { return false }
                let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
                return date >= weekAgo
            }
        case .month:
            walks = walks.filter { walk in
                guard let date = walk.startedAt?.dateValue() else { return false }
                let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
                return date >= monthAgo
            }
        }

        switch sortOption {
        case .date:
            walks.sort { ($0.startedAt?.dateValue() ?? Date()) > ($1.startedAt?.dateValue() ?? Date()) }
        case .distance:
            walks.sort { $0.distanceMeters > $1.distanceMeters }
        case .duration:
            walks.sort { $0.durationSec > $1.durationSec }
        }

        return walks
    }

    private var groupedWalks: [(String, [WalkHistory])] {
        let groups = Dictionary(grouping: filteredWalks) { walk -> String in
            guard let date = walk.startedAt?.dateValue() else { return "Unknown" }
            let calendar = Calendar.current
            let now = Date()

            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
                return "This Week"
            } else if let monthAgo = calendar.date(byAdding: .month, value: -1, to: now), date >= monthAgo {
                return "This Month"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)
            }
        }

        let sortOrder: [String] = ["Today", "Yesterday", "This Week", "This Month"]
        return groups.sorted { lhs, rhs in
            let lhsIndex = sortOrder.firstIndex(of: lhs.key) ?? Int.max
            let rhsIndex = sortOrder.firstIndex(of: rhs.key) ?? Int.max
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            return lhs.key < rhs.key
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading && viewModel.walks.isEmpty {
                    ProgressView()
                } else if viewModel.walks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No walks yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Start tracking your first walk!")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if let stats = viewModel.statistics {
                                WalkStatsSummaryCard(stats: stats)
                                    .padding(.horizontal)
                            }

                            ForEach(groupedWalks, id: \.0) { group in
                                Section {
                                    ForEach(group.1) { walk in
                                        NavigationLink(destination: WalkDetailView(walkId: walk.id ?? "")) {
                                            WalkCardView(walk: walk) {}
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                } header: {
                                    Text(group.0)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.top, 8)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Walk History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        Picker("Filter", selection: $filterOption) {
                            ForEach(FilterOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search walks")
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.error ?? "Unknown error")
            }
        }
        .onAppear {
            viewModel.loadWalks()
        }
    }
}

struct WalkStatsSummaryCard: View {
    let stats: WalkStatsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Statistics")
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 0) {
                WalkHistoryStatItem(
                    label: "Total Walks",
                    value: "\(stats.totalWalks)"
                )
                Spacer()
                WalkHistoryStatItem(
                    label: "Total Distance",
                    value: String(format: "%.1f km", Double(stats.totalDistanceMeters) / 1000.0)
                )
                Spacer()
                WalkHistoryStatItem(
                    label: "Avg Speed",
                    value: String(format: "%.1f km/h", stats.avgSpeedKmh)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct WalkHistoryStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct WalkStatsSummary {
    let totalWalks: Int
    let totalDistanceMeters: Double
    let totalTimeMinutes: Int
    let avgSpeedKmh: Double

    init(totalWalks: Int = 0, totalDistanceMeters: Double = 0, totalTimeMinutes: Int = 0, avgSpeedKmh: Double = 0) {
        self.totalWalks = totalWalks
        self.totalDistanceMeters = totalDistanceMeters
        self.totalTimeMinutes = totalTimeMinutes
        self.avgSpeedKmh = avgSpeedKmh
    }
}
