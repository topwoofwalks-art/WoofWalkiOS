import SwiftUI
import FirebaseFirestore

// MARK: - View Model

@MainActor
class MilestoneTrackerViewModel: ObservableObject {
    @Published var milestones: [PuppyMilestone] = []
    @Published var communityMilestones: [PuppyMilestone] = []
    @Published var selectedDog: String = "All"
    @Published var dogNames: [String] = ["All"]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAddSheet = false
    @Published var selectedTab = 0

    private let db = Firestore.firestore()
    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    static let milestoneTypes = [
        "First Walk", "First Bath", "First Vet Visit", "House Trained",
        "Learned Sit", "Learned Stay", "Learned Recall", "First Grooming",
        "Socialization Complete", "Teething Done", "First Birthday",
        "First Off-Lead Walk", "First Swimming", "Vaccination Complete"
    ]

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts")
                .whereField("type", isEqualTo: CommunityPostType.PUPPY_MILESTONE.rawValue)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            let allMilestones = posts.compactMap { post -> PuppyMilestone? in
                guard let meta = post.metadata else { return nil }
                return PuppyMilestone(
                    id: post.id,
                    communityId: communityId,
                    postId: post.id ?? "",
                    dogName: meta["dogName"] ?? "",
                    milestoneType: meta["milestoneType"] ?? "",
                    title: post.title,
                    description: post.content,
                    photoUrls: post.mediaUrls,
                    ageWeeks: Int(meta["ageWeeks"] ?? "0") ?? 0,
                    createdBy: post.authorId,
                    createdAt: post.createdAt
                )
            }

            communityMilestones = allMilestones

            // Extract unique dog names
            let names = Set(allMilestones.map { $0.dogName }).sorted()
            dogNames = ["All"] + names

            applyFilter()
            isLoading = false
        } catch {
            errorMessage = "Failed to load milestones"
            isLoading = false
        }
    }

    func applyFilter() {
        if selectedDog == "All" {
            milestones = communityMilestones
        } else {
            milestones = communityMilestones.filter { $0.dogName == selectedDog }
        }
    }

    func formatAge(_ weeks: Int) -> String {
        if weeks < 4 { return "\(weeks) week\(weeks == 1 ? "" : "s")" }
        let months = weeks / 4
        if months < 12 { return "\(months) month\(months == 1 ? "" : "s")" }
        let years = months / 12
        let remainMonths = months % 12
        if remainMonths == 0 { return "\(years) year\(years == 1 ? "" : "s")" }
        return "\(years)y \(remainMonths)m"
    }
}

// MARK: - View

struct MilestoneTrackerView: View {
    let communityId: String
    @StateObject private var viewModel: MilestoneTrackerViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: MilestoneTrackerViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $viewModel.selectedTab) {
                Text("Timeline").tag(0)
                Text("Community Feed").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Dog selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.dogNames, id: \.self) { dog in
                        Button {
                            viewModel.selectedDog = dog
                            viewModel.applyFilter()
                        } label: {
                            HStack(spacing: 4) {
                                if dog != "All" {
                                    Image(systemName: "pawprint.fill")
                                        .font(.caption2)
                                }
                                Text(dog)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(viewModel.selectedDog == dog ? Color.turquoise60 : Color(.systemGray6)))
                            .foregroundColor(viewModel.selectedDog == dog ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.milestones.isEmpty {
                emptyState
            } else {
                ScrollView {
                    if viewModel.selectedTab == 0 {
                        timelineView
                    } else {
                        communityFeedView
                    }
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

    // MARK: - Timeline

    private var timelineView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.milestones.enumerated()), id: \.element.id) { index, milestone in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.turquoise60)
                            .frame(width: 12, height: 12)
                        if index < viewModel.milestones.count - 1 {
                            Rectangle()
                                .fill(Color.turquoise60.opacity(0.3))
                                .frame(width: 2)
                        }
                    }
                    .frame(width: 12)

                    // Milestone card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(milestone.milestoneType)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(viewModel.formatAge(milestone.ageWeeks))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.turquoise90))
                                .foregroundColor(.turquoise30)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "pawprint.fill")
                                .font(.caption2)
                                .foregroundColor(.turquoise60)
                            Text(milestone.dogName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !milestone.title.isEmpty {
                            Text(milestone.title)
                                .font(.subheadline)
                        }

                        if !milestone.description.isEmpty {
                            Text(milestone.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }

                        if let firstUrl = milestone.photoUrls.first, let url = URL(string: firstUrl) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.neutral90)
                            }
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Text(formatDate(milestone.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 3, y: 1))
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Community Feed

    private var communityFeedView: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.communityMilestones) { milestone in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.yellow)
                        Text(milestone.dogName)
                            .font(.subheadline.bold())
                        Text("reached a milestone!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    HStack {
                        Text(milestone.milestoneType)
                            .font(.headline)
                        Spacer()
                        Text(viewModel.formatAge(milestone.ageWeeks))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(.systemGray6)))
                            .foregroundColor(.secondary)
                    }

                    if !milestone.description.isEmpty {
                        Text(milestone.description)
                            .font(.body)
                    }

                    if !milestone.photoUrls.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(milestone.photoUrls, id: \.self) { urlString in
                                    if let url = URL(string: urlString) {
                                        AsyncImage(url: url) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: {
                                            Rectangle().fill(Color.neutral90)
                                        }
                                        .frame(width: 160, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }

                    Text(formatDate(milestone.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.05), radius: 3, y: 1))
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "star.circle")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No Milestones Yet")
                .font(.headline)
            Text("Track your puppy's important moments and share them with the community")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.showAddSheet = true
            } label: {
                Label("Add Milestone", systemImage: "plus.circle")
                    .font(.subheadline.bold())
                    .foregroundColor(.turquoise60)
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding()
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
