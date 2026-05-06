import SwiftUI

/// Members tab — shows non-banned members sorted by role then recency.
/// Owner-only actions appear in a context menu (kick / ban / promote).
/// Banning offers a reason field (real ban-with-reason — UX fix from
/// Android's audit, no more silent kick).
struct CommunityMembersTab: View {
    @ObservedObject var viewModel: CommunityDetailViewModel

    @State private var memberToBan: CommunityMember?
    @State private var banReason: String = ""

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.members.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.members) { member in
                    row(for: member)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 12)
        .alert("Ban member?", isPresented: Binding(
            get: { memberToBan != nil },
            set: { if !$0 { memberToBan = nil; banReason = "" } }
        )) {
            TextField("Reason (optional)", text: $banReason)
            Button("Cancel", role: .cancel) { memberToBan = nil; banReason = "" }
            Button("Ban", role: .destructive) {
                if let m = memberToBan, !m.userId.isEmpty {
                    Task { await viewModel.banMember(m.userId, reason: banReason) }
                }
                memberToBan = nil
                banReason = ""
            }
        } message: {
            Text("They won't be able to post or comment. You can unban later from Moderation.")
        }
    }

    @ViewBuilder
    private func row(for member: CommunityMember) -> some View {
        HStack(spacing: 12) {
            avatar(for: member)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName.isEmpty ? "Unknown" : member.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !member.bio.isEmpty {
                    Text(member.bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if !member.dogNames.isEmpty {
                    Text(member.dogNames.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            roleChip(for: member)
            if showActionsForCurrentUser(target: member) {
                Menu {
                    actionsMenu(for: member)
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func avatar(for member: CommunityMember) -> some View {
        if let urlStr = member.photoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.secondary.opacity(0.4))
        }
    }

    @ViewBuilder
    private func roleChip(for member: CommunityMember) -> some View {
        if member.role != .member {
            Text(member.role.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(roleColor(member.role).opacity(0.18))
                .foregroundColor(roleColor(member.role))
                .clipShape(Capsule())
        }
    }

    private func roleColor(_ role: CommunityMemberRole) -> Color {
        switch role {
        case .owner: return .purple
        case .admin: return .blue
        case .moderator: return .green
        case .member: return .secondary
        }
    }

    private func showActionsForCurrentUser(target: CommunityMember) -> Bool {
        guard let me = viewModel.currentMember else { return false }
        if !me.canModerate { return false }
        if target.userId == me.userId { return false }
        if target.isOwner { return false }
        return true
    }

    @ViewBuilder
    private func actionsMenu(for member: CommunityMember) -> some View {
        if let me = viewModel.currentMember {
            if me.canAdmin {
                if member.role != .moderator {
                    Button {
                        Task { await viewModel.updateMemberRole(member.userId, role: .moderator) }
                    } label: {
                        Label("Make Moderator", systemImage: "shield")
                    }
                }
                if member.role != .admin {
                    Button {
                        Task { await viewModel.updateMemberRole(member.userId, role: .admin) }
                    } label: {
                        Label("Make Admin", systemImage: "star")
                    }
                }
                if member.role != .member {
                    Button {
                        Task { await viewModel.updateMemberRole(member.userId, role: .member) }
                    } label: {
                        Label("Demote to Member", systemImage: "person")
                    }
                }
                if me.isOwner {
                    Button {
                        Task { await viewModel.updateMemberRole(member.userId, role: .owner) }
                    } label: {
                        Label("Transfer Ownership", systemImage: "crown")
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                Task { await viewModel.kickMember(member.userId) }
            } label: {
                Label("Remove from Community", systemImage: "person.crop.circle.badge.minus")
            }
            Button(role: .destructive) {
                memberToBan = member
            } label: {
                Label("Ban...", systemImage: "hand.raised")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No members yet")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
