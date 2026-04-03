import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommunityDetailScreen: View {
    let communityId: String
    @StateObject private var viewModel: CommunityDetailViewModel
    @State private var selectedTab = 0

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: CommunityDetailViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let community = viewModel.community {
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection(community)
                        tabBar(community)
                    }
                }

                // Tab content
                tabContent(community)
            } else {
                emptyState
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isAdmin {
                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            communitySettingsSheet
        }
    }

    // MARK: - Header

    private func headerSection(_ community: CommunityDetail) -> some View {
        VStack(spacing: 12) {
            // Cover photo
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(community.type.color.opacity(0.15))
                    .frame(height: 140)
                Image(systemName: community.type.icon)
                    .font(.system(size: 40))
                    .foregroundColor(community.type.color.opacity(0.3))
            }

            VStack(spacing: 8) {
                Text(community.name)
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    Label(community.type.displayName, systemImage: community.type.icon)
                        .font(.caption)
                        .foregroundColor(community.type.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(community.type.color.opacity(0.12)))

                    Label("\(community.memberCount) members", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if community.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !community.description.isEmpty {
                    Text(community.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Join / Leave button
                Button(action: {
                    Task { await viewModel.toggleMembership() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isMember ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(viewModel.isMember ? "Joined" : "Join Community")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(viewModel.isMember ? brandColor : .white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(viewModel.isMember ? brandColor.opacity(0.12) : brandColor)
                    )
                    .overlay(
                        Capsule().strokeBorder(brandColor, lineWidth: viewModel.isMember ? 1 : 0)
                    )
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Tab Bar

    private func tabBar(_ community: CommunityDetail) -> some View {
        let tabs = tabTitles(for: community.type)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                    } label: {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? brandColor : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .overlay(alignment: .bottom) {
                        if selectedTab == index {
                            Rectangle()
                                .fill(brandColor)
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(
            Rectangle()
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private func tabTitles(for type: CommunityType) -> [String] {
        var titles = ["Feed", "Events", "Chat", "Members"]
        switch type {
        case .training: titles.append("Resources")
        case .breedSpecific: titles.append("Gallery")
        case .rescue: titles.append("Adoptable")
        case .sport: titles.append("Leaderboard")
        default: break
        }
        return titles
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(_ community: CommunityDetail) -> some View {
        switch selectedTab {
        case 0:
            CommunityFeedTab(communityId: communityId)
        case 1:
            CommunityEventsTab(communityId: communityId)
        case 2:
            CommunityChatTab(communityId: communityId)
        case 3:
            CommunityMembersTab(communityId: communityId, isAdmin: viewModel.isAdmin)
        default:
            typeSpecificTab(community.type)
        }
    }

    @ViewBuilder
    private func typeSpecificTab(_ type: CommunityType) -> some View {
        switch type {
        case .training:
            placeholderTab(icon: "book.fill", title: "Resources", message: "Training resources coming soon.")
        case .breedSpecific:
            placeholderTab(icon: "photo.on.rectangle.angled", title: "Gallery", message: "Breed photo gallery coming soon.")
        case .rescue:
            placeholderTab(icon: "heart.fill", title: "Adoptable Dogs", message: "Adoptable dogs listing coming soon.")
        case .sport:
            placeholderTab(icon: "trophy.fill", title: "Leaderboard", message: "Sport leaderboard coming soon.")
        default:
            EmptyView()
        }
    }

    private func placeholderTab(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty / Settings

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Community not found")
                .font(.title3.bold())
            Spacer()
        }
    }

    private var communitySettingsSheet: some View {
        NavigationStack {
            List {
                Section("General") {
                    Label("Edit Name & Description", systemImage: "pencil")
                    Label("Change Cover Photo", systemImage: "photo")
                    Label("Manage Tags", systemImage: "tag")
                }
                Section("Privacy") {
                    Label("Visibility Settings", systemImage: "eye")
                    Label("Join Rules", systemImage: "person.badge.plus")
                }
                Section("Danger Zone") {
                    Label("Delete Community", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { viewModel.showSettings = false }
                }
            }
        }
    }
}

// MARK: - Detail Model

struct CommunityDetail {
    let id: String
    let name: String
    let description: String
    let type: CommunityType
    let memberCount: Int
    let coverPhotoUrl: String?
    let isPrivate: Bool
    let ownerId: String
    let adminIds: [String]
    let memberIds: [String]
    let tags: [String]
    let rules: String
}

// MARK: - ViewModel

@MainActor
class CommunityDetailViewModel: ObservableObject {
    @Published var community: CommunityDetail?
    @Published var isLoading = false
    @Published var isMember = false
    @Published var isAdmin = false
    @Published var showSettings = false

    private let communityId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let currentUserId: String

    init(communityId: String) {
        self.communityId = communityId
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadCommunity()
    }

    func loadCommunity() {
        isLoading = true
        listener = db.collection("communities").document(communityId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Community detail error: \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data(), let name = data["name"] as? String else {
                    self.community = nil
                    return
                }
                let typeRaw = data["type"] as? String ?? "social"
                let type = CommunityType(rawValue: typeRaw) ?? .social
                let adminIds = data["adminIds"] as? [String] ?? []
                let memberIds = data["memberIds"] as? [String] ?? []
                let ownerId = data["ownerId"] as? String ?? ""

                self.community = CommunityDetail(
                    id: snapshot?.documentID ?? self.communityId,
                    name: name,
                    description: data["description"] as? String ?? "",
                    type: type,
                    memberCount: data["memberCount"] as? Int ?? memberIds.count,
                    coverPhotoUrl: data["coverPhotoUrl"] as? String,
                    isPrivate: data["isPrivate"] as? Bool ?? false,
                    ownerId: ownerId,
                    adminIds: adminIds,
                    memberIds: memberIds,
                    tags: data["tags"] as? [String] ?? [],
                    rules: data["rules"] as? String ?? ""
                )

                self.isMember = memberIds.contains(self.currentUserId)
                self.isAdmin = adminIds.contains(self.currentUserId) || ownerId == self.currentUserId
            }
    }

    func toggleMembership() async {
        guard !currentUserId.isEmpty else { return }
        let ref = db.collection("communities").document(communityId)
        do {
            if isMember {
                try await ref.updateData([
                    "memberIds": FieldValue.arrayRemove([currentUserId]),
                    "memberCount": FieldValue.increment(Int64(-1)),
                ])
            } else {
                try await ref.updateData([
                    "memberIds": FieldValue.arrayUnion([currentUserId]),
                    "memberCount": FieldValue.increment(Int64(1)),
                ])
            }
        } catch {
            print("Toggle membership error: \(error.localizedDescription)")
        }
    }

    deinit { listener?.remove() }
}
