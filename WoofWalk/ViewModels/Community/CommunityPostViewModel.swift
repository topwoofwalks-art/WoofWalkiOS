import Foundation
import FirebaseAuth
import Combine

/// Drives `CommunityPostDetailScreen`. Holds live post + threaded comments,
/// and exposes commands for reactions, comment-like, comment-add (with
/// `parentCommentId` for threading), report-with-reason, and delete.
@MainActor
final class CommunityPostViewModel: ObservableObject {
    @Published var post: CommunityPost?
    @Published var comments: [CommunityComment] = []
    @Published var isLoading: Bool = false
    @Published var isPostingComment: Bool = false
    @Published var error: String?

    let communityId: String
    let postId: String
    let currentUserId: String?

    private let repository: CommunityPostRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        communityId: String,
        postId: String,
        repository: CommunityPostRepository = .shared
    ) {
        self.communityId = communityId
        self.postId = postId
        self.repository = repository
        self.currentUserId = Auth.auth().currentUser?.uid
        bind()
    }

    private func bind() {
        isLoading = true
        repository.listenPost(communityId: communityId, postId: postId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] post in
                self?.post = post
                self?.isLoading = false
            }
            .store(in: &cancellables)

        repository.listenComments(communityId: communityId, postId: postId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] comments in
                self?.comments = comments
            }
            .store(in: &cancellables)
    }

    // MARK: - Threaded view helpers

    /// Top-level comments (no parent) sorted oldest-first.
    var topLevelComments: [CommunityComment] {
        comments.filter { $0.parentCommentId == nil }
    }

    /// Replies to a given parent comment, sorted oldest-first.
    func replies(to parentId: String) -> [CommunityComment] {
        comments.filter { $0.parentCommentId == parentId }
    }

    // MARK: - Actions

    func toggleReaction(_ type: CommunityReactionType) async {
        do {
            try await repository.toggleReaction(communityId: communityId, postId: postId, reactionType: type.rawValue)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleBookmark() async {
        do {
            try await repository.toggleBookmark(communityId: communityId, postId: postId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func votePoll(optionId: String) async {
        do {
            try await repository.votePoll(communityId: communityId, postId: postId, optionId: optionId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addComment(content: String, parentCommentId: String? = nil) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isPostingComment = true
        let comment = CommunityComment(
            postId: postId,
            communityId: communityId,
            content: trimmed,
            parentCommentId: parentCommentId
        )
        do {
            _ = try await repository.addComment(comment)
        } catch {
            self.error = error.localizedDescription
        }
        isPostingComment = false
    }

    func toggleCommentLike(_ commentId: String) async {
        do {
            try await repository.toggleCommentLike(communityId: communityId, postId: postId, commentId: commentId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteComment(_ commentId: String) async {
        do {
            try await repository.deleteComment(communityId: communityId, postId: postId, commentId: commentId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Report this post. The reason+description are recorded in
    /// `community_reports`; CFs handle moderator notification.
    func reportPost(reason: CommunityReportReason, description: String = "") async {
        guard let post else { return }
        do {
            _ = try await repository.reportContent(
                communityId: communityId,
                targetType: .post,
                targetId: postId,
                targetAuthorId: post.authorId,
                reason: reason,
                description: description
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reportComment(_ commentId: String, reason: CommunityReportReason, description: String = "") async {
        let comment = comments.first(where: { $0.id == commentId })
        do {
            _ = try await repository.reportContent(
                communityId: communityId,
                targetType: .comment,
                targetId: commentId,
                targetAuthorId: comment?.authorId ?? "",
                reason: reason,
                description: description
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deletePost() async {
        do {
            try await repository.deletePost(communityId: communityId, postId: postId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearError() { error = nil }
}
