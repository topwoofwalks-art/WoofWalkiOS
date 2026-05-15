import SwiftUI

/// Moderation screen for admins+moderators. Three tabs:
///   - Reports: pending content reports → resolve / dismiss + review note
///   - Join Requests (private only): approve / reject
///   - Members: kick / ban / role-change actions
///
/// Real ban-with-reason (Android audit fix from `ec9cbc2` — was a silent
/// kick before).
struct CommunityModerationScreen: View {
    let communityId: String

    @StateObject private var viewModel: CommunityModerationViewModel
    @State private var selectedTab: ModerationTab = .reports

    private enum ModerationTab: Int, CaseIterable, Identifiable {
        case reports
        case joinRequests
        case members

        var id: Int { rawValue }
        var title: String {
            switch self {
            case .reports: return "Reports"
            case .joinRequests: return "Requests"
            case .members: return "Members"
            }
        }
    }

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: CommunityModerationViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(ModerationTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            ScrollView {
                switch selectedTab {
                case .reports: reportsList
                case .joinRequests: joinRequestsList
                case .members: membersList
                }
            }
        }
        .navigationTitle("Moderation")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Reports

    private var reportsList: some View {
        VStack(spacing: 10) {
            if viewModel.reports.isEmpty {
                emptyState(
                    icon: "shield.checkered",
                    title: "No reports",
                    subtitle: "Pending reports will show up here."
                )
            } else {
                ForEach(viewModel.reports) { report in
                    ReportRow(report: report) { status, note in
                        guard let id = report.id else { return }
                        Task { await viewModel.resolveReport(id, status: status, reviewNote: note) }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Join requests

    private var joinRequestsList: some View {
        VStack(spacing: 10) {
            if viewModel.pendingJoinRequests.isEmpty {
                emptyState(
                    icon: "person.badge.plus",
                    title: "No requests",
                    subtitle: "Pending requests to join this community will appear here."
                )
            } else {
                ForEach(viewModel.pendingJoinRequests) { request in
                    JoinRequestRow(
                        request: request,
                        onApprove: {
                            guard let id = request.id else { return }
                            Task { await viewModel.approveJoinRequest(id) }
                        },
                        onReject: {
                            guard let id = request.id else { return }
                            Task { await viewModel.rejectJoinRequest(id) }
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Members

    private var membersList: some View {
        VStack(spacing: 10) {
            if viewModel.members.isEmpty {
                emptyState(
                    icon: "person.3",
                    title: "No members",
                    subtitle: "This shouldn't normally happen."
                )
            } else {
                ForEach(viewModel.members) { member in
                    MemberRow(
                        member: member,
                        onKick: {
                            Task { await viewModel.kickMember(member.userId) }
                        },
                        onBan: { reason in
                            Task { await viewModel.banMember(member.userId, reason: reason) }
                        },
                        onRoleChange: { role in
                            Task { await viewModel.updateRole(member.userId, role: role) }
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundColor(.secondary.opacity(0.4))
            Text(title).font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - ReportRow

private struct ReportRow: View {
    let report: CommunityReport
    let onResolve: (CommunityReportStatus, String) -> Void

    @State private var note: String = ""
    @State private var showResolutionInput: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: report.reason.iconSystemName)
                    .foregroundColor(.red)
                Text(report.reason.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(report.targetType.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
            if !report.description.isEmpty {
                Text(report.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            HStack {
                Text("Reporter: \(report.reporterUserName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(reportTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if showResolutionInput {
                TextField("Resolution note (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                if showResolutionInput {
                    Button {
                        onResolve(.resolved, note)
                        showResolutionInput = false
                        note = ""
                    } label: {
                        Text("Confirm Resolve")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    Button {
                        showResolutionInput = false
                        note = ""
                    } label: {
                        Text("Cancel")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                } else {
                    Button {
                        showResolutionInput = true
                    } label: {
                        Text("Resolve")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.18))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                    Button {
                        onResolve(.dismissed, "")
                    } label: {
                        Text("Dismiss")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var reportTime: String {
        let date = Date(timeIntervalSince1970: report.createdAt / 1000)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - JoinRequestRow

private struct JoinRequestRow: View {
    let request: CommunityJoinRequest
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.userName.isEmpty ? "Anonymous" : request.userName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if !request.message.isEmpty {
                        Text(request.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Button(action: onApprove) {
                    Text("Approve")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                Button(action: onReject) {
                    Text("Reject")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var avatar: some View {
        UserAvatarView(photoUrl: request.userPhotoUrl, displayName: request.userName, size: 36)
    }
}

// MARK: - MemberRow

private struct MemberRow: View {
    let member: CommunityMember
    let onKick: () -> Void
    let onBan: (String) -> Void
    let onRoleChange: (CommunityMemberRole) -> Void

    @State private var showBanInput: Bool = false
    @State private var banReason: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(member.displayName.isEmpty ? "Unknown" : member.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(member.role.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(roleColor(member.role).opacity(0.15))
                    .foregroundColor(roleColor(member.role))
                    .clipShape(Capsule())
                if !member.isOwner && !showBanInput {
                    Menu {
                        // Promote ladder: MEMBER → MODERATOR → ADMIN. Each
                        // step appears only if the member isn't already at
                        // or above that rank.
                        if member.role == .member {
                            Button {
                                onRoleChange(.moderator)
                            } label: {
                                Label("Promote to Moderator", systemImage: "arrow.up.circle")
                            }
                        }
                        if member.role == .moderator {
                            Button {
                                onRoleChange(.admin)
                            } label: {
                                Label("Promote to Admin", systemImage: "arrow.up.circle.fill")
                            }
                        }
                        // Demote ladder: ADMIN → MODERATOR → MEMBER.
                        if member.role == .admin {
                            Button {
                                onRoleChange(.moderator)
                            } label: {
                                Label("Demote to Moderator", systemImage: "arrow.down.circle")
                            }
                        }
                        if member.role == .moderator {
                            Button {
                                onRoleChange(.member)
                            } label: {
                                Label("Demote to Member", systemImage: "arrow.down.circle")
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            onKick()
                        } label: {
                            Label("Kick", systemImage: "person.crop.circle.badge.xmark")
                        }
                        Button(role: .destructive) {
                            showBanInput = true
                        } label: {
                            Label("Ban", systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Member actions")
                }
            }
            if showBanInput {
                TextField("Ban reason (optional)", text: $banReason)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        onBan(banReason)
                        showBanInput = false
                        banReason = ""
                    } label: {
                        Text("Confirm Ban")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    Button {
                        showBanInput = false
                        banReason = ""
                    } label: {
                        Text("Cancel")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func roleColor(_ role: CommunityMemberRole) -> Color {
        switch role {
        case .owner: return .purple
        case .admin: return .blue
        case .moderator: return .green
        case .member: return .secondary
        }
    }
}
