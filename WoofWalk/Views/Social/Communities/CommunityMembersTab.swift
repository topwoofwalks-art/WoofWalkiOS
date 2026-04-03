import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommunityMembersTab: View {
    let communityId: String
    let isAdmin: Bool
    @StateObject private var viewModel: CommunityMembersViewModel

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    init(communityId: String, isAdmin: Bool) {
        self.communityId = communityId
        self.isAdmin = isAdmin
        _viewModel = StateObject(wrappedValue: CommunityMembersViewModel(communityId: communityId))
    }

    var body: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.allMembers.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "person.3")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.3))
                Text("No Members")
                    .font(.title3.bold())
                Spacer()
            }
        } else {
            List {
                // Owner
                if let owner = viewModel.owner {
                    Section("Owner") {
                        MemberRow(member: owner, role: .owner, isAdmin: isAdmin) { action in
                            Task { await viewModel.performAction(action, on: owner.id) }
                        }
                    }
                }

                // Admins
                if !viewModel.admins.isEmpty {
                    Section("Admins") {
                        ForEach(viewModel.admins) { member in
                            MemberRow(member: member, role: .admin, isAdmin: isAdmin) { action in
                                Task { await viewModel.performAction(action, on: member.id) }
                            }
                        }
                    }
                }

                // Members
                if !viewModel.members.isEmpty {
                    Section("Members (\(viewModel.members.count))") {
                        ForEach(viewModel.members) { member in
                            MemberRow(member: member, role: .member, isAdmin: isAdmin) { action in
                                Task { await viewModel.performAction(action, on: member.id) }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - Models

enum MemberRole: String {
    case owner
    case admin
    case member

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .owner: return .orange
        case .admin: return .blue
        case .member: return .secondary
        }
    }
}

enum MemberAction {
    case promote
    case demote
    case remove
}

struct CommunityMember: Identifiable {
    let id: String
    let displayName: String
    let photoUrl: String?
    let joinedAt: Date
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: CommunityMember
    let role: MemberRole
    let isAdmin: Bool
    let onAction: (MemberAction) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.subheadline)
                Text("Joined \(formatDate(member.joinedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(role.displayName)
                .font(.caption2.bold())
                .foregroundColor(role.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(role.color.opacity(0.12)))
        }
        .contextMenu {
            if isAdmin && role != .owner {
                if role == .member {
                    Button {
                        onAction(.promote)
                    } label: {
                        Label("Promote to Admin", systemImage: "arrow.up.circle")
                    }
                }
                if role == .admin {
                    Button {
                        onAction(.demote)
                    } label: {
                        Label("Demote to Member", systemImage: "arrow.down.circle")
                    }
                }
                Button(role: .destructive) {
                    onAction(.remove)
                } label: {
                    Label("Remove from Community", systemImage: "person.badge.minus")
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
class CommunityMembersViewModel: ObservableObject {
    @Published var allMembers: [CommunityMember] = []
    @Published var isLoading = false

    var owner: CommunityMember? { allMembers.first(where: { ownerIds.contains($0.id) }) }
    var admins: [CommunityMember] { allMembers.filter { adminIds.contains($0.id) && !ownerIds.contains($0.id) } }
    var members: [CommunityMember] { allMembers.filter { !adminIds.contains($0.id) && !ownerIds.contains($0.id) } }

    private let communityId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var ownerIds: Set<String> = []
    private var adminIds: Set<String> = []

    init(communityId: String) {
        self.communityId = communityId
        loadMembers()
    }

    func loadMembers() {
        isLoading = true
        listener = db.collection("communities").document(communityId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Members error: \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data() else { return }
                let ownerId = data["ownerId"] as? String ?? ""
                let adminIdList = data["adminIds"] as? [String] ?? []
                let memberIdList = data["memberIds"] as? [String] ?? []

                self.ownerIds = Set([ownerId])
                self.adminIds = Set(adminIdList + [ownerId])

                // Build member list from memberIds
                self.allMembers = memberIdList.map { uid in
                    CommunityMember(
                        id: uid,
                        displayName: uid == ownerId ? "Owner" : "Member",
                        photoUrl: nil,
                        joinedAt: Date()
                    )
                }

                // Fetch display names
                self.fetchUserNames(for: memberIdList)
            }
    }

    private func fetchUserNames(for userIds: [String]) {
        guard !userIds.isEmpty else { return }
        // Firestore IN queries limited to 30
        let chunks = stride(from: 0, to: userIds.count, by: 30).map {
            Array(userIds[$0..<min($0 + 30, userIds.count)])
        }
        for chunk in chunks {
            db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { [weak self] snapshot, error in
                    guard let self, let docs = snapshot?.documents else { return }
                    Task { @MainActor in
                        for doc in docs {
                            let data = doc.data()
                            let name = data["displayName"] as? String ?? data["name"] as? String ?? "User"
                            let photoUrl = data["photoUrl"] as? String
                            let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date()
                            if let index = self.allMembers.firstIndex(where: { $0.id == doc.documentID }) {
                                self.allMembers[index] = CommunityMember(
                                    id: doc.documentID,
                                    displayName: name,
                                    photoUrl: photoUrl,
                                    joinedAt: joinedAt
                                )
                            }
                        }
                    }
                }
        }
    }

    func performAction(_ action: MemberAction, on userId: String) async {
        let ref = db.collection("communities").document(communityId)
        do {
            switch action {
            case .promote:
                try await ref.updateData([
                    "adminIds": FieldValue.arrayUnion([userId]),
                ])
            case .demote:
                try await ref.updateData([
                    "adminIds": FieldValue.arrayRemove([userId]),
                ])
            case .remove:
                try await ref.updateData([
                    "memberIds": FieldValue.arrayRemove([userId]),
                    "adminIds": FieldValue.arrayRemove([userId]),
                    "memberCount": FieldValue.increment(Int64(-1)),
                ])
            }
        } catch {
            print("Member action error: \(error.localizedDescription)")
        }
    }

    deinit { listener?.remove() }
}
