import SwiftUI

/// Community detail with tabbed pager:
///   - Feed (pinned section + posts with like / comment / bookmark)
///   - Events (upcoming events with attend toggle)
///   - Chat (group chat bubbles with day separators + retry)
///   - Members (list with role chips + owner-only actions)
///   - + a type-specific tab when applicable (Adoptions / Milestones / etc.)
///
/// Header is 140pt cover — UX fix from Android (was 200dp originally; the
/// audit found it dominated the screen).
struct CommunityDetailScreen: View {
    let communityId: String

    @StateObject private var viewModel: CommunityDetailViewModel
    @State private var showCreatePost = false
    @State private var showSettings = false
    @State private var showModeration = false
    @State private var showLeaveConfirm = false

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: CommunityDetailViewModel(communityId: communityId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                tabBar
                tabContent
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.community?.name ?? "Community")
                    .font(.headline)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if (viewModel.myRole?.canModerate ?? false) {
                        Button {
                            showModeration = true
                        } label: {
                            Label("Moderation", systemImage: "shield")
                        }
                    }
                    if (viewModel.myRole?.canAdmin ?? false) {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                    if viewModel.isMember && !(viewModel.myRole?.isOwner ?? false) {
                        Button(role: .destructive) {
                            showLeaveConfirm = true
                        } label: {
                            Label("Leave Community", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            if let community = viewModel.community {
                CommunitySettingsScreen(community: community, viewModel: viewModel)
            }
        }
        .navigationDestination(isPresented: $showModeration) {
            CommunityModerationScreen(communityId: communityId)
        }
        .fullScreenCover(isPresented: $showCreatePost) {
            CreateCommunityPostScreen(communityId: communityId, viewModel: viewModel) {
                showCreatePost = false
            }
        }
        .alert("Leave Community?", isPresented: $showLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await viewModel.leaveCommunity() }
            }
        } message: {
            Text("You can rejoin later if it's public.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            coverImage
                .frame(height: 140)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 6) {
                if let community = viewModel.community {
                    HStack(spacing: 6) {
                        CommunityTypeBadge(type: community.type)
                        if community.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        if community.isFeatured {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                Text("Featured")
                            }
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.yellow.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    Text(community.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    HStack(spacing: 12) {
                        Label("\(community.memberCount) members", systemImage: "person.3.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.92))
                        joinButton
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let urlStr = viewModel.community?.coverPhotoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    placeholderColor
                }
            }
        } else {
            placeholderColor
        }
    }

    private var placeholderColor: some View {
        let c = viewModel.community?.type.color ?? (red: 0.3, green: 0.5, blue: 0.6)
        return Color(red: c.red, green: c.green, blue: c.blue).opacity(0.7)
    }

    @ViewBuilder
    private var joinButton: some View {
        if viewModel.isMember {
            Text(viewModel.myRole?.displayName ?? "Member")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())
        } else {
            Button {
                Task { await viewModel.joinCommunity() }
            } label: {
                Text(viewModel.community?.privacy == .private ? "Request to Join" : "Join")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Self.brandColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tabs

    private var availableTabs: [CommunityDetailTab] {
        var tabs: [CommunityDetailTab] = [.feed, .events, .chat, .members]
        if viewModel.hasTypeSpecificTab {
            tabs.append(.typeSpecific)
        }
        return tabs
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(availableTabs) { tab in
                    let isSelected = viewModel.selectedTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewModel.selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: tab == .typeSpecific
                                    ? (viewModel.community?.type.iconSystemName ?? "star")
                                    : tab.iconSystemName)
                                    .font(.system(size: 13))
                                Text(tab == .typeSpecific ? viewModel.typeSpecificTabTitle : tab.title)
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .semibold : .regular)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            Rectangle()
                                .fill(isSelected ? Self.brandColor : Color.clear)
                                .frame(height: 2)
                        }
                        .foregroundColor(isSelected ? Self.brandColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .feed:
            CommunityFeedTab(viewModel: viewModel) {
                showCreatePost = true
            }
        case .events:
            CommunityEventsTab(viewModel: viewModel)
        case .chat:
            CommunityChatTab(viewModel: viewModel)
        case .members:
            CommunityMembersTab(viewModel: viewModel)
        case .typeSpecific:
            CommunityFeedTab(viewModel: viewModel, typeSpecificMode: true) {
                showCreatePost = true
            }
        }
    }
}
