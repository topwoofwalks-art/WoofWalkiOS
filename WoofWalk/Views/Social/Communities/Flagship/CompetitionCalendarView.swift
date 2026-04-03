import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - View Model

@MainActor
class CompetitionCalendarViewModel: ObservableObject {
    @Published var competitions: [CompetitionEntry] = []
    @Published var selectedType: String = "All"
    @Published var selectedTab = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAddSheet = false

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    static let competitionTypes = ["All", "Agility", "Show", "Flyball", "Obedience", "Rally", "Dock Diving", "Canicross", "Other"]

    var filteredCompetitions: [CompetitionEntry] {
        var results = competitions
        if selectedType != "All" {
            results = results.filter { $0.competitionType.lowercased() == selectedType.lowercased() }
        }
        return results.sorted { $0.eventDate > $1.eventDate }
    }

    var upcomingCompetitions: [CompetitionEntry] {
        let now = Date().timeIntervalSince1970 * 1000
        return filteredCompetitions.filter { $0.eventDate >= now }.sorted { $0.eventDate < $1.eventDate }
    }

    var pastCompetitions: [CompetitionEntry] {
        let now = Date().timeIntervalSince1970 * 1000
        return filteredCompetitions.filter { $0.eventDate < now }
    }

    var personalRecords: [(type: String, bestScore: Double, bestPlacement: String, entry: CompetitionEntry)] {
        guard let uid = auth.currentUser?.uid else { return [] }
        let myEntries = competitions.filter { $0.createdBy == uid }
        let grouped = Dictionary(grouping: myEntries) { $0.competitionType }

        return grouped.compactMap { type, entries in
            let bestByScore = entries.filter { $0.score != nil }.max { ($0.score ?? 0) < ($1.score ?? 0) }
            let bestEntry = bestByScore ?? entries.first!
            return (
                type: type,
                bestScore: bestByScore?.score ?? 0,
                bestPlacement: bestByScore?.placement ?? "N/A",
                entry: bestEntry
            )
        }
        .sorted { $0.bestScore > $1.bestScore }
    }

    var leaderboard: [(name: String, totalScore: Double, medals: Int, entries: Int)] {
        let grouped = Dictionary(grouping: competitions) { $0.dogName }
        return grouped.map { name, entries in
            let total = entries.reduce(0.0) { $0 + ($1.score ?? 0) }
            let medals = entries.filter { placement in
                let p = placement.placement?.lowercased() ?? ""
                return p.contains("1st") || p.contains("2nd") || p.contains("3rd") || p == "1" || p == "2" || p == "3"
            }.count
            return (name: name, totalScore: total, medals: medals, entries: entries.count)
        }
        .sorted { $0.totalScore > $1.totalScore }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts")
                .whereField("type", isEqualTo: CommunityPostType.COMPETITION_ENTRY.rawValue)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            competitions = posts.compactMap { post -> CompetitionEntry? in
                guard let meta = post.metadata else { return nil }
                return CompetitionEntry(
                    id: post.id,
                    communityId: communityId,
                    postId: post.id ?? "",
                    dogName: meta["dogName"] ?? post.authorName,
                    competitionName: meta["competitionName"] ?? post.title,
                    competitionType: meta["competitionType"] ?? "Other",
                    eventDate: Double(meta["eventDate"] ?? "0") ?? post.createdAt,
                    locationName: post.locationName ?? "",
                    placement: meta["placement"],
                    score: Double(meta["score"] ?? ""),
                    photoUrls: post.mediaUrls,
                    notes: post.content,
                    createdBy: post.authorId,
                    createdAt: post.createdAt
                )
            }
            isLoading = false
        } catch {
            errorMessage = "Failed to load competitions"
            isLoading = false
        }
    }

    func typeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "agility": return .blue
        case "show": return .purple
        case "flyball": return .orange
        case "obedience": return .green
        case "rally": return .red
        case "dock diving": return .cyan
        case "canicross": return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .secondary
        }
    }

    func typeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "agility": return "figure.run"
        case "show": return "rosette"
        case "flyball": return "tennisball.fill"
        case "obedience": return "hand.raised.fill"
        case "rally": return "flag.fill"
        case "dock diving": return "water.waves"
        case "canicross": return "figure.run.circle.fill"
        default: return "trophy"
        }
    }
}

// MARK: - View

struct CompetitionCalendarView: View {
    let communityId: String
    @StateObject private var viewModel: CompetitionCalendarViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: CompetitionCalendarViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $viewModel.selectedTab) {
                Text("Upcoming").tag(0)
                Text("Results").tag(1)
                Text("Records").tag(2)
                Text("Leaderboard").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Type filter
            if viewModel.selectedTab < 2 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CompetitionCalendarViewModel.competitionTypes, id: \.self) { type in
                            Button {
                                viewModel.selectedType = type
                            } label: {
                                HStack(spacing: 4) {
                                    if type != "All" {
                                        Image(systemName: viewModel.typeIcon(type))
                                            .font(.caption2)
                                    }
                                    Text(type)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(viewModel.selectedType == type ? Color.turquoise60 : Color(.systemGray6)))
                                .foregroundColor(viewModel.selectedType == type ? .white : .primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                switch viewModel.selectedTab {
                case 0: upcomingView
                case 1: resultsView
                case 2: personalRecordsView
                case 3: leaderboardView
                default: EmptyView()
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Entry")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.turquoise60))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            CreateCommunityPostSheet(communityId: communityId) {
                Task { await viewModel.load() }
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Upcoming

    private var upcomingView: some View {
        Group {
            if viewModel.upcomingCompetitions.isEmpty {
                emptyState(icon: "calendar", title: "No Upcoming Competitions", message: "No competitions scheduled yet. Add one to get the community excited!")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.upcomingCompetitions) { entry in
                            CompetitionCard(entry: entry, viewModel: viewModel, showResult: false)
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.load() }
            }
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        Group {
            if viewModel.pastCompetitions.isEmpty {
                emptyState(icon: "trophy", title: "No Results Yet", message: "Past competition results will appear here")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.pastCompetitions) { entry in
                            CompetitionCard(entry: entry, viewModel: viewModel, showResult: true)
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.load() }
            }
        }
    }

    // MARK: - Personal Records

    private var personalRecordsView: some View {
        Group {
            if viewModel.personalRecords.isEmpty {
                emptyState(icon: "medal", title: "No Personal Records", message: "Enter competitions to start tracking your records")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.personalRecords, id: \.type) { record in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: viewModel.typeIcon(record.type))
                                        .foregroundColor(viewModel.typeColor(record.type))
                                    Text(record.type)
                                        .font(.headline)
                                    Spacer()
                                }

                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Best Score")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(record.bestScore > 0 ? String(format: "%.1f", record.bestScore) : "N/A")
                                            .font(.title3.bold())
                                            .foregroundColor(.turquoise60)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Best Placement")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(record.bestPlacement)
                                            .font(.title3.bold())
                                    }

                                    Spacer()
                                }

                                Text(record.entry.competitionName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.06), radius: 4, y: 2))
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardView: some View {
        Group {
            if viewModel.leaderboard.isEmpty {
                emptyState(icon: "list.number", title: "No Leaderboard Data", message: "Competition entries with scores will populate the leaderboard")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.name) { index, entry in
                            HStack(spacing: 12) {
                                // Rank
                                if index < 3 {
                                    ZStack {
                                        Circle().fill(medalColor(index)).frame(width: 32, height: 32)
                                        Text("\(index + 1)").font(.caption2.bold()).foregroundColor(.white)
                                    }
                                } else {
                                    Text("#\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                        .frame(width: 32)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.subheadline.bold())
                                    Text("\(entry.entries) entr\(entry.entries == 1 ? "y" : "ies")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if entry.medals > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "medal.fill")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                        Text("\(entry.medals)")
                                            .font(.caption)
                                    }
                                }

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.0f", entry.totalScore))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.turquoise60)
                                    Text("points")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)

                            if index < viewModel.leaderboard.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
                    .padding()
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.showAddSheet = true
            } label: {
                Label("Add Competition", systemImage: "plus.circle")
                    .font(.subheadline.bold())
                    .foregroundColor(.turquoise60)
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding()
    }

    private func medalColor(_ index: Int) -> Color {
        switch index {
        case 0: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 1: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .secondary
        }
    }
}

// MARK: - Competition Card

private struct CompetitionCard: View {
    let entry: CompetitionEntry
    let viewModel: CompetitionCalendarViewModel
    let showResult: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                // Type badge
                HStack(spacing: 4) {
                    Image(systemName: viewModel.typeIcon(entry.competitionType))
                        .font(.caption)
                    Text(entry.competitionType)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(viewModel.typeColor(entry.competitionType).opacity(0.15)))
                .foregroundColor(viewModel.typeColor(entry.competitionType))

                Spacer()

                Text(formatDate(entry.eventDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(entry.competitionName)
                .font(.headline)

            // Dog & Location
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption2)
                    Text(entry.dogName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                if !entry.locationName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(entry.locationName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
            }

            // Results (if showing)
            if showResult {
                HStack(spacing: 16) {
                    if let placement = entry.placement, !placement.isEmpty {
                        VStack(spacing: 2) {
                            Text(placement)
                                .font(.title3.bold())
                                .foregroundColor(.turquoise60)
                            Text("Place")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let score = entry.score {
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", score))
                                .font(.title3.bold())
                            Text("Score")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.turquoise90.opacity(0.3)))
            }

            // Photos
            if !entry.photoUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.photoUrls, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.neutral90)
                                }
                                .frame(width: 80, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }

            // Notes
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.06), radius: 4, y: 2))
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
