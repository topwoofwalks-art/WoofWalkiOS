import SwiftUI

/// Feed tab shown inside `CommunityDetailScreen`. Renders pinned posts in a
/// dedicated section then regular posts below. Each post supports the LIKE
/// reaction (heart icon + count), bookmark, share to detail, and inline
/// reactor avatars when count > 0.
struct CommunityFeedTab: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    var typeSpecificMode: Bool = false
    let onCreatePost: () -> Void

    @State private var selectedPostId: String?

    private var displayedPosts: [CommunityPost] {
        typeSpecificMode ? viewModel.typeSpecificPosts : viewModel.posts
    }

    private var pinnedDisplayed: [CommunityPost] {
        typeSpecificMode ? [] : viewModel.pinnedPosts
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isMember {
                createPostPrompt
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            if !pinnedDisplayed.isEmpty {
                sectionHeader("Pinned")
                ForEach(pinnedDisplayed) { post in
                    PostCard(
                        post: post,
                        currentUserId: viewModel.currentUserId,
                        onTap: { if let id = post.id { selectedPostId = id } },
                        onLike: {
                            if let id = post.id {
                                Task { await viewModel.togglePostLike(id) }
                            }
                        },
                        onBookmark: {
                            if let id = post.id {
                                Task { await viewModel.togglePostBookmark(id) }
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }

            if displayedPosts.isEmpty && pinnedDisplayed.isEmpty {
                emptyFeedState
            } else if !displayedPosts.isEmpty {
                if !pinnedDisplayed.isEmpty {
                    sectionHeader("Latest")
                }
                ForEach(displayedPosts) { post in
                    PostCard(
                        post: post,
                        currentUserId: viewModel.currentUserId,
                        onTap: { if let id = post.id { selectedPostId = id } },
                        onLike: {
                            if let id = post.id {
                                Task { await viewModel.togglePostLike(id) }
                            }
                        },
                        onBookmark: {
                            if let id = post.id {
                                Task { await viewModel.togglePostBookmark(id) }
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 12)
        // iOS 16-compatible navigationDestination — `item:` overload is
        // iOS 17+. Bind via isPresented + cached selectedPostId.
        .navigationDestination(isPresented: Binding(
            get: { selectedPostId != nil },
            set: { if !$0 { selectedPostId = nil } }
        )) {
            if let id = selectedPostId {
                CommunityPostDetailScreen(communityId: viewModel.communityId, postId: id)
            }
        }
    }

    private var createPostPrompt: some View {
        Button(action: onCreatePost) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Share something with the community...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var emptyFeedState: some View {
        VStack(spacing: 10) {
            Image(systemName: "newspaper")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.4))
            Text(typeSpecificMode ? "No featured posts yet" : "No posts yet")
                .font(.headline)
            Text(typeSpecificMode
                 ? "Specialised posts for this community will appear here."
                 : "Be the first to post in this community.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - PostCard

/// Single post cell — used both in the feed (compact) and as the header on
/// the post detail. Tap-target is the whole card; the like / bookmark
/// buttons stop propagation so they don't open detail.
struct PostCard: View {
    let post: CommunityPost
    let currentUserId: String?
    let onTap: () -> Void
    let onLike: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                authorRow
                if !post.title.isEmpty {
                    Text(post.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                }
                if !post.content.isEmpty {
                    Text(post.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(8)
                }
                if !post.mediaUrls.isEmpty {
                    mediaPreview
                }
                if post.isPoll && !post.pollOptions.isEmpty {
                    pollPreview
                }
                actionRow
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(post.authorName.isEmpty ? "Unknown" : post.authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if post.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if post.type != .text {
                        Text(post.type.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if post.isEdited {
                Text("Edited")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlStr = post.authorPhotoUrl, let url = URL(string: urlStr) {
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
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(.secondary.opacity(0.4))
        }
    }

    private var relativeTime: String {
        let date = Date(timeIntervalSince1970: post.createdAt / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @ViewBuilder
    private var mediaPreview: some View {
        if let firstUrl = post.mediaUrls.first, let url = URL(string: firstUrl) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.secondary.opacity(0.15)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if post.mediaUrls.count > 1 {
                    Text("+\(post.mediaUrls.count - 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
        }
    }

    private var pollPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(post.pollOptions.prefix(4)) { opt in
                HStack {
                    Text(opt.text)
                        .font(.subheadline)
                    Spacer()
                    Text("\(opt.voteCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            Button(action: onLike) {
                HStack(spacing: 4) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .foregroundColor(liked ? .red : .secondary)
                    Text("\(post.likeCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .foregroundColor(.secondary)
                Text("\(post.commentCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onBookmark) {
                Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundColor(bookmarked ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
        }
        .font(.body)
    }

    private var liked: Bool {
        guard let uid = currentUserId else { return false }
        return post.isLikedBy(uid) || post.userReaction(userId: uid) != nil
    }

    private var bookmarked: Bool {
        guard let uid = currentUserId else { return false }
        return post.isBookmarkedBy(uid)
    }
}
