import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Skill Level

enum SkillLevel: Int, CaseIterable {
    case beginner = 0
    case novice = 25
    case intermediate = 50
    case advanced = 75
    case mastered = 100

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .novice: return "Novice"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .mastered: return "Mastered"
        }
    }

    var color: Color {
        switch self {
        case .beginner: return .gray
        case .novice: return .blue
        case .intermediate: return .green
        case .advanced: return .orange
        case .mastered: return .purple
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "circle"
        case .novice: return "circle.bottomhalf.filled"
        case .intermediate: return "circle.inset.filled"
        case .advanced: return "star.circle.fill"
        case .mastered: return "crown.fill"
        }
    }

    static func from(percent: Int) -> SkillLevel {
        switch percent {
        case 0..<25: return .beginner
        case 25..<50: return .novice
        case 50..<75: return .intermediate
        case 75..<100: return .advanced
        default: return .mastered
        }
    }
}

// MARK: - View Model

@MainActor
class TrainingProgressViewModel: ObservableObject {
    @Published var skills: [TrainingProgress] = []
    @Published var communitySkills: [TrainingProgress] = []
    @Published var selectedCategory: String = "All"
    @Published var selectedTab = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAddSheet = false
    @Published var selectedSkill: TrainingProgress?

    private let db = Firestore.firestore()
    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    static let categories = ["All", "Obedience", "Agility", "Tricks", "Socialization", "Recall", "Leash Training", "Other"]

    var filteredSkills: [TrainingProgress] {
        let source = selectedTab == 0 ? skills : communitySkills
        if selectedCategory == "All" { return source }
        return source.filter { $0.category == selectedCategory }
    }

    var leaderboard: [(name: String, totalProgress: Int, skillCount: Int)] {
        let grouped = Dictionary(grouping: communitySkills) { $0.dogName }
        return grouped.map { name, skills in
            let total = skills.reduce(0) { $0 + $1.progressPercent }
            return (name: name, totalProgress: total, skillCount: skills.count)
        }
        .sorted { $0.totalProgress > $1.totalProgress }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts")
                .whereField("type", isEqualTo: CommunityPostType.TRAINING_TIP.rawValue)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            communitySkills = posts.compactMap { post -> TrainingProgress? in
                guard let meta = post.metadata else { return nil }
                return TrainingProgress(
                    id: post.id,
                    communityId: communityId,
                    postId: post.id ?? "",
                    dogName: meta["dogName"] ?? post.authorName,
                    skillName: meta["skillName"] ?? post.title,
                    category: meta["category"] ?? "Other",
                    progressPercent: Int(meta["progress"] ?? "0") ?? 0,
                    notes: post.content,
                    videoUrl: post.mediaUrls.first(where: { $0.contains("video") }),
                    createdBy: post.authorId,
                    createdAt: post.createdAt,
                    updatedAt: post.updatedAt
                )
            }

            // Filter my skills
            let uid = Auth.auth().currentUser?.uid ?? ""
            skills = communitySkills.filter { $0.createdBy == uid }

            isLoading = false
        } catch {
            errorMessage = "Failed to load training progress"
            isLoading = false
        }
    }
}

// MARK: - View

struct TrainingProgressView: View {
    let communityId: String
    @StateObject private var viewModel: TrainingProgressViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: TrainingProgressViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $viewModel.selectedTab) {
                Text("My Skills").tag(0)
                Text("Community").tag(1)
                Text("Leaderboard").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Category filter
            if viewModel.selectedTab != 2 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TrainingProgressViewModel.categories, id: \.self) { cat in
                            Button {
                                viewModel.selectedCategory = cat
                            } label: {
                                Text(cat)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(viewModel.selectedCategory == cat ? Color.turquoise60 : Color(.systemGray6)))
                                    .foregroundColor(viewModel.selectedCategory == cat ? .white : .primary)
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
            } else if viewModel.selectedTab == 2 {
                leaderboardView
            } else if viewModel.filteredSkills.isEmpty {
                emptyState
            } else {
                ScrollView {
                    skillsGrid
                }
                .refreshable { await viewModel.load() }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.turquoise60))
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

    // MARK: - Skills Grid

    private var skillsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.filteredSkills) { skill in
                SkillCard(skill: skill)
                    .onTapGesture { viewModel.selectedSkill = skill }
            }
        }
        .padding()
    }

    // MARK: - Leaderboard

    private var leaderboardView: some View {
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
                            Text("\(entry.skillCount) skill\(entry.skillCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(entry.totalProgress)")
                                .font(.subheadline.bold())
                                .foregroundColor(.turquoise60)
                            Text("total XP")
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "graduationcap")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No Training Progress")
                .font(.headline)
            Text(viewModel.selectedTab == 0
                 ? "Start tracking your dog's training skills"
                 : "No community training updates yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.showAddSheet = true
            } label: {
                Label("Add Training Update", systemImage: "plus.circle")
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
        case 0: return Color(red: 1.0, green: 0.84, blue: 0.0) // gold
        case 1: return Color(red: 0.75, green: 0.75, blue: 0.75) // silver
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2) // bronze
        default: return .secondary
        }
    }
}

// MARK: - Skill Card

private struct SkillCard: View {
    let skill: TrainingProgress

    private var level: SkillLevel {
        SkillLevel.from(percent: skill.progressPercent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: level.icon)
                    .foregroundColor(level.color)
                Spacer()
                Text(level.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(level.color.opacity(0.15)))
                    .foregroundColor(level.color)
            }

            Text(skill.skillName)
                .font(.subheadline.bold())
                .lineLimit(2)

            if !skill.category.isEmpty {
                Text(skill.category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !skill.dogName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption2)
                    Text(skill.dogName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(skill.progressPercent), total: 100)
                    .tint(level.color)
                Text("\(skill.progressPercent)%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Sessions
            if skill.sessionsCompleted > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption2)
                    Text("\(skill.sessionsCompleted) sessions")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.06), radius: 4, y: 2))
    }
}
