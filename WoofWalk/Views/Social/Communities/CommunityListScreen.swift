import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models

enum CommunityType: String, CaseIterable, Identifiable {
    case breedSpecific = "breed_specific"
    case neighborhood = "neighborhood"
    case training = "training"
    case rescue = "rescue"
    case social = "social"
    case sport = "sport"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breedSpecific: return "Breed"
        case .neighborhood: return "Neighborhood"
        case .training: return "Training"
        case .rescue: return "Rescue"
        case .social: return "Social"
        case .sport: return "Sport"
        }
    }

    var icon: String {
        switch self {
        case .breedSpecific: return "pawprint.fill"
        case .neighborhood: return "house.fill"
        case .training: return "graduationcap.fill"
        case .rescue: return "heart.fill"
        case .social: return "person.3.fill"
        case .sport: return "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .breedSpecific: return .orange
        case .neighborhood: return .green
        case .training: return .blue
        case .rescue: return .pink
        case .social: return .purple
        case .sport: return .red
        }
    }
}

struct CommunityItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let type: CommunityType
    let memberCount: Int
    let coverPhotoUrl: String?
    let isPrivate: Bool
    let tags: [String]
    let createdAt: Date
}

// MARK: - View

struct CommunityListScreen: View {
    @StateObject private var viewModel = CommunityListViewModel()
    @State private var searchText = ""
    @State private var selectedType: CommunityType?
    @State private var showCreateSheet = false

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search communities...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 16)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            icon: "square.grid.2x2",
                            isSelected: selectedType == nil,
                            color: brandColor
                        ) {
                            selectedType = nil
                        }

                        ForEach(CommunityType.allCases) { type in
                            FilterChip(
                                title: type.displayName,
                                icon: type.icon,
                                isSelected: selectedType == type,
                                color: type.color
                            ) {
                                selectedType = selectedType == type ? nil : type
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // My Communities
                if !viewModel.myCommunities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Communities")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.myCommunities) { community in
                                    NavigationLink(value: community) {
                                        MyCommunityCard(community: community)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                // Trending
                if !viewModel.trendingCommunities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trending")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ForEach(viewModel.trendingCommunities) { community in
                            NavigationLink(value: community) {
                                TrendingCommunityRow(community: community)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Discover
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discover")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredCommunities) { community in
                            NavigationLink(value: community) {
                                CommunityCard(community: community)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(for: CommunityItem.self) { community in
            CommunityDetailScreen(communityId: community.id)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(brandColor))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
            .padding(16)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCommunitySheet()
        }
        .overlay {
            if viewModel.isLoading && viewModel.discoverCommunities.isEmpty {
                ProgressView()
            }
        }
    }

    private var filteredCommunities: [CommunityItem] {
        var results = viewModel.discoverCommunities
        if let type = selectedType {
            results = results.filter { $0.type == type }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }
        return results
    }
}

// MARK: - Subviews

private struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? color : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? color.opacity(0.12) : Color(.systemGray6))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MyCommunityCard: View {
    let community: CommunityItem
    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover photo placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(community.type.color.opacity(0.2))
                    .frame(width: 120, height: 70)
                Image(systemName: community.type.icon)
                    .font(.title2)
                    .foregroundColor(community.type.color.opacity(0.5))
            }

            Text(community.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: 2) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 8))
                Text("\(community.memberCount)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
    }
}

private struct TrendingCommunityRow: View {
    let community: CommunityItem
    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(community.type.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: community.type.icon)
                    .foregroundColor(community.type.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(community.name)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Text(community.type.displayName)
                        .font(.caption2)
                        .foregroundColor(community.type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(community.type.color.opacity(0.12)))
                    Text("\(community.memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
                .font(.caption)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}

private struct CommunityCard: View {
    let community: CommunityItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover photo placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(community.type.color.opacity(0.15))
                    .frame(height: 80)
                Image(systemName: community.type.icon)
                    .font(.title2)
                    .foregroundColor(community.type.color.opacity(0.4))
            }

            Text(community.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(community.type.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(community.type.color)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(community.type.color.opacity(0.12)))

                Spacer()

                Image(systemName: "person.2.fill")
                    .font(.system(size: 8))
                Text("\(community.memberCount)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}

// MARK: - ViewModel

@MainActor
class CommunityListViewModel: ObservableObject {
    @Published var myCommunities: [CommunityItem] = []
    @Published var trendingCommunities: [CommunityItem] = []
    @Published var discoverCommunities: [CommunityItem] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let currentUserId: String

    init() {
        currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadCommunities()
    }

    func loadCommunities() {
        guard !currentUserId.isEmpty else { return }
        isLoading = true

        listener = db.collection("communities")
            .order(by: "memberCount", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Communities error: \(error.localizedDescription)")
                    return
                }
                let docs = snapshot?.documents ?? []
                let communities: [CommunityItem] = docs.compactMap { doc in
                    self.parseCommunity(doc: doc)
                }

                self.discoverCommunities = communities
                self.myCommunities = communities.filter { community in
                    docs.contains { doc in
                        let members = doc.data()["memberIds"] as? [String] ?? []
                        return doc.documentID == community.id && members.contains(self.currentUserId)
                    }
                }
                self.trendingCommunities = Array(communities.prefix(5))
            }
    }

    func refresh() async {
        loadCommunities()
        // Brief pause to allow snapshot listener to update
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    private func parseCommunity(doc: QueryDocumentSnapshot) -> CommunityItem? {
        let data = doc.data()
        guard let name = data["name"] as? String else { return nil }
        let typeRaw = data["type"] as? String ?? "social"
        let type = CommunityType(rawValue: typeRaw) ?? .social
        return CommunityItem(
            id: doc.documentID,
            name: name,
            description: data["description"] as? String ?? "",
            type: type,
            memberCount: data["memberCount"] as? Int ?? 0,
            coverPhotoUrl: data["coverPhotoUrl"] as? String,
            isPrivate: data["isPrivate"] as? Bool ?? false,
            tags: data["tags"] as? [String] ?? [],
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    deinit { listener?.remove() }
}
