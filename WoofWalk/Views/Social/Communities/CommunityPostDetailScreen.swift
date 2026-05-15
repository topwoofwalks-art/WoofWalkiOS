import SwiftUI

/// Full post screen: author header → content → media gallery → poll voting
/// → reaction bar (5 emoji types) → reactors-list sheet → threaded
/// comments → comment-like → report-with-reason → share via
/// UIActivityViewController.
///
/// The reaction bar is always visible (not hover-revealed like Android's
/// long-press) — iOS users discover the typed-reaction picker via the
/// emoji bar, tapping the heart still defaults to LIKE for parity.
struct CommunityPostDetailScreen: View {
    let communityId: String
    let postId: String

    @StateObject private var viewModel: CommunityPostViewModel
    @State private var commentText: String = ""
    @State private var replyingToCommentId: String?
    @State private var replyingToCommentName: String?
    @State private var showReactors: Bool = false
    @State private var showReportSheet: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false

    init(communityId: String, postId: String) {
        self.communityId = communityId
        self.postId = postId
        _viewModel = StateObject(wrappedValue: CommunityPostViewModel(communityId: communityId, postId: postId))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if let post = viewModel.post {
                    VStack(alignment: .leading, spacing: 14) {
                        authorHeader(post: post)
                        if !post.title.isEmpty {
                            Text(post.title)
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        if !post.content.isEmpty {
                            Text(post.content)
                                .font(.body)
                        }
                        mediaGallery(post: post)
                        if post.isPoll {
                            pollSection(post: post)
                        }
                        reactionBar(post: post)
                        Divider()
                        commentsSection
                    }
                    .padding(16)
                } else if viewModel.isLoading {
                    ProgressView().padding()
                } else {
                    Text("Post not found.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            commentInputBar
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if viewModel.post?.authorId == viewModel.currentUserId {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    }
                    Button {
                        showReportSheet = true
                    } label: {
                        Label("Report", systemImage: "flag")
                    }
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showReactors) {
            ReactorsListSheet(post: viewModel.post)
        }
        .sheet(isPresented: $showReportSheet) {
            CommunityReportSheet { reason, description in
                Task { await viewModel.reportPost(reason: reason, description: description) }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let post = viewModel.post {
                let shareText = postShareText(post: post)
                ShareSheet(activityItems: [shareText])
            }
        }
        .alert("Delete this post?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.deletePost() }
            }
        } message: {
            Text("This cannot be undone.")
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

    // MARK: - Author header

    private func authorHeader(post: CommunityPost) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(photoUrl: post.authorPhotoUrl, displayName: post.authorName, size: 44)
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
                }
                HStack(spacing: 6) {
                    Text(relativeTime(post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if post.type != .text {
                        Text(post.type.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if post.isEdited {
                        Text("Edited")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                Task { await viewModel.toggleBookmark() }
            } label: {
                Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundColor(bookmarked ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func avatarFor(urlStr: String?, size: CGFloat) -> some View {
        if let urlStr, let url = URL(string: urlStr) {
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
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: size, height: size)
                .foregroundColor(.secondary.opacity(0.4))
        }
    }

    private func relativeTime(_ ms: Double) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Media gallery

    @ViewBuilder
    private func mediaGallery(post: CommunityPost) -> some View {
        if !post.mediaUrls.isEmpty {
            TabView {
                ForEach(post.mediaUrls, id: \.self) { urlStr in
                    if let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fit)
                            default:
                                Color.secondary.opacity(0.15)
                            }
                        }
                    }
                }
            }
            .frame(height: 280)
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Poll

    @ViewBuilder
    private func pollSection(post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Poll")
                .font(.subheadline)
                .fontWeight(.semibold)
            ForEach(post.pollOptions) { opt in
                let total = max(1, post.pollOptions.reduce(0) { $0 + $1.voteCount })
                let pct = Double(opt.voteCount) / Double(total)
                let voted = viewModel.currentUserId.map { opt.isVotedBy($0) } ?? false
                Button {
                    Task { await viewModel.votePoll(optionId: opt.id) }
                } label: {
                    ZStack(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(voted ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.15))
                                .frame(width: geo.size.width * pct)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        HStack {
                            Text(opt.text)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(Int((pct * 100).rounded()))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("·")
                                .foregroundColor(.secondary)
                            Text("\(opt.voteCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
            if post.isPollExpired {
                Text("Poll closed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Reaction bar

    private func reactionBar(post: CommunityPost) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                ForEach(CommunityReactionType.allCases) { type in
                    let mine = viewModel.currentUserId.map { (post.userReaction(userId: $0) ?? "") == type.rawValue } ?? false
                    let count = post.reactions[type.rawValue]?.count ?? 0
                    Button {
                        Task { await viewModel.toggleReaction(type) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(type.emoji)
                                .font(.system(size: mine ? 26 : 22))
                            Text("\(count)")
                                .font(.caption2)
                                .foregroundColor(mine ? .accentColor : .secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(mine ? Color.accentColor.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    showReactors = true
                } label: {
                    Text("\(post.likeCount) \(post.likeCount == 1 ? "reaction" : "reactions")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(post.likeCount == 0)
            }
        }
    }

    private var bookmarked: Bool {
        guard let uid = viewModel.currentUserId, let post = viewModel.post else { return false }
        return post.isBookmarkedBy(uid)
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments (\(viewModel.comments.count))")
                .font(.subheadline)
                .fontWeight(.semibold)
            if viewModel.topLevelComments.isEmpty {
                Text("Be the first to comment.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.topLevelComments) { comment in
                    commentTree(comment: comment, depth: 0)
                }
            }
        }
    }

    // Recursive comment tree. Returns AnyView so the recursion has a
    // concrete return type — `some View` doesn't work here because the
    // opaque type would have to be defined in terms of itself (Swift
    // 5.7+ catches this as a Release-build error; Debug had been silent).
    private func commentTree(comment: CommunityComment, depth: Int) -> AnyView {
        let replies = viewModel.replies(to: comment.id ?? "")
        return AnyView(
            Group {
                commentRow(comment: comment, depth: depth)
                ForEach(replies) { reply in
                    commentTree(comment: reply, depth: depth + 1)
                }
            }
        )
    }

    private func commentRow(comment: CommunityComment, depth: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            UserAvatarView(photoUrl: comment.authorPhotoUrl, displayName: comment.authorName, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorName.isEmpty ? "Unknown" : comment.authorName)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(relativeTime(comment.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(comment.content)
                    .font(.subheadline)
                HStack(spacing: 14) {
                    Button {
                        if let id = comment.id {
                            Task { await viewModel.toggleCommentLike(id) }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            let liked = viewModel.currentUserId.map { comment.isLikedBy($0) } ?? false
                            Image(systemName: liked ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor(liked ? .red : .secondary)
                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Button("Reply") {
                        replyingToCommentId = comment.id
                        replyingToCommentName = comment.authorName
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if comment.authorId == viewModel.currentUserId {
                        Button(role: .destructive) {
                            if let id = comment.id {
                                Task { await viewModel.deleteComment(id) }
                            }
                        } label: {
                            Text("Delete")
                                .font(.caption)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.leading, CGFloat(depth) * 28)
    }

    // MARK: - Comment input bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            if let replyingToName = replyingToCommentName {
                HStack {
                    Text("Replying to ").foregroundColor(.secondary).font(.caption)
                    + Text(replyingToName).fontWeight(.semibold).font(.caption)
                    Spacer()
                    Button {
                        replyingToCommentId = nil
                        replyingToCommentName = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
            }
            HStack(spacing: 10) {
                TextField("Add a comment...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Button {
                    let parent = replyingToCommentId
                    let text = commentText
                    Task {
                        await viewModel.addComment(content: text, parentCommentId: parent)
                        commentText = ""
                        replyingToCommentId = nil
                        replyingToCommentName = nil
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22))
                        .foregroundColor(canSendComment ? .accentColor : .secondary.opacity(0.4))
                }
                .disabled(!canSendComment || viewModel.isPostingComment)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(alignment: .top) {
                Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 0.5)
            }
        }
    }

    private var canSendComment: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Helpers

    private func postShareText(post: CommunityPost) -> String {
        let header = post.title.isEmpty ? "Community post" : post.title
        let body = post.content
        return [header, body].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

// MARK: - Reactors list

private struct ReactorsListSheet: View {
    let post: CommunityPost?

    var body: some View {
        NavigationStack {
            List {
                if let post {
                    ForEach(CommunityReactionType.allCases) { type in
                        let users = post.reactions[type.rawValue] ?? []
                        if !users.isEmpty {
                            Section(header: HStack {
                                Text(type.emoji)
                                Text(type.label)
                                Text("(\(users.count))")
                                    .foregroundColor(.secondary)
                            }) {
                                ForEach(users, id: \.self) { uid in
                                    Text(uid)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Report sheet

struct CommunityReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reason: CommunityReportReason = .other
    @State private var description: String = ""

    let onSubmit: (CommunityReportReason, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Why are you reporting this?")) {
                    ForEach(CommunityReportReason.allCases) { r in
                        Button {
                            reason = r
                        } label: {
                            HStack {
                                Image(systemName: r.iconSystemName)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 22)
                                Text(r.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if reason == r {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                Section(header: Text("Additional details (optional)")) {
                    TextField("Add details...", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        onSubmit(reason, description)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
