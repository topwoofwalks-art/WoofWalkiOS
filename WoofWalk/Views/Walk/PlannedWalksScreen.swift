import SwiftUI
import Combine

struct PlannedWalksScreen: View {
    @StateObject private var viewModel = PlannedWalksViewModel()
    @State private var selectedTab = 0
    @State private var selectedWalk: PlannedWalk?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Upcoming").tag(0)
                Text("Completed").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                switch selectedTab {
                case 0:
                    PlannedWalksList(
                        walks: viewModel.upcomingWalks,
                        emptyMessage: "No upcoming walks planned yet",
                        emptyIcon: "calendar.badge.plus",
                        onSelect: { selectedWalk = $0 },
                        onDelete: { viewModel.deleteWalk(id: $0) }
                    )
                default:
                    PlannedWalksList(
                        walks: viewModel.completedWalks,
                        emptyMessage: "No completed planned walks",
                        emptyIcon: "checkmark.circle",
                        onSelect: { selectedWalk = $0 },
                        onDelete: { viewModel.deleteWalk(id: $0) }
                    )
                }
            }
        }
        .navigationTitle("Planned Walks")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedWalk) { walk in
            PlannedWalkDetailSheet(
                walk: walk,
                onStartWalk: {
                    selectedWalk = nil
                    // Pass the planned walk to the map for guided execution
                    AppNavigator.shared.pendingPlannedWalk = walk
                    AppNavigator.shared.selectedTab = .map
                },
                onDelete: {
                    viewModel.deleteWalk(id: walk.id ?? "")
                    selectedWalk = nil
                }
            )
        }
    }
}

// MARK: - Planned Walks List

private struct PlannedWalksList: View {
    let walks: [PlannedWalk]
    let emptyMessage: String
    let emptyIcon: String
    let onSelect: (PlannedWalk) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        if walks.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: emptyIcon)
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text(emptyMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List {
                ForEach(walks) { walk in
                    PlannedWalkCard(walk: walk)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(walk) }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        if let walkId = walks[index].id {
                            onDelete(walkId)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Planned Walk Card

private struct PlannedWalkCard: View {
    let walk: PlannedWalk

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(walk.title)
                        .font(.headline)
                        .lineLimit(1)
                    if !walk.startLocationName.isEmpty {
                        Text(walk.startLocationName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let date = walk.plannedForDate {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundColor(.turquoise30)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.turquoise90)
                        )
                }
            }

            HStack(spacing: 16) {
                Label(FormatUtils.formatDistance(walk.estimatedDistanceMeters), systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundColor(.turquoise60)

                Label(FormatUtils.formatDuration(Int(walk.estimatedDurationSec)), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !walk.routePolyline.isEmpty {
                    Label("\(walk.routePolyline.count) pts", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !walk.dogIds.isEmpty {
                    HStack(spacing: -4) {
                        ForEach(0..<min(walk.dogIds.count, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.turquoise90)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Image(systemName: "pawprint.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.turquoise60)
                                )
                        }
                        if walk.dogIds.count > 3 {
                            Circle()
                                .fill(Color.neutral90)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Text("+\(walk.dogIds.count - 3)")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.neutral30)
                                )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    private func formatDate(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Tomorrow \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd, HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - ViewModel

@MainActor
class PlannedWalksViewModel: ObservableObject {
    @Published var upcomingWalks: [PlannedWalk] = []
    @Published var completedWalks: [PlannedWalk] = []
    @Published var isLoading = true

    private let repository = PlannedWalkRepository()
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadPlannedWalks()
    }

    private func loadPlannedWalks() {
        isLoading = true

        repository.getPlannedWalks()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("PlannedWalksViewModel: Error loading walks: \(error.localizedDescription)")
                    }
                    self?.isLoading = false
                },
                receiveValue: { [weak self] walks in
                    guard let self = self else { return }
                    let now = Int64(Date().timeIntervalSince1970 * 1000)

                    self.upcomingWalks = walks
                        .filter { ($0.plannedForDate ?? 0) > now && $0.completedWalkId == nil }
                        .sorted { ($0.plannedForDate ?? 0) < ($1.plannedForDate ?? 0) }

                    self.completedWalks = walks
                        .filter { $0.completedWalkId != nil || ($0.plannedForDate ?? Int64.max) <= now }
                        .sorted { ($0.plannedForDate ?? 0) > ($1.plannedForDate ?? 0) }

                    self.isLoading = false
                }
            )
            .store(in: &cancellables)
    }

    func deleteWalk(id: String) {
        Task {
            do {
                try await repository.deletePlannedWalk(id: id)
            } catch {
                print("PlannedWalksViewModel: Error deleting walk: \(error.localizedDescription)")
            }
        }
    }
}
