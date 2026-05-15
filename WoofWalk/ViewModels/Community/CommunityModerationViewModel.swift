import Foundation
import FirebaseAuth
import Combine

/// Drives `CommunityModerationScreen`. Exposes pending reports, pending join
/// requests, and the action commands (resolve / approve / reject / ban /
/// kick / hide post). Mirrors Android's `CommunityModerationViewModel`.
@MainActor
final class CommunityModerationViewModel: ObservableObject {
    @Published var reports: [CommunityReport] = []
    @Published var pendingJoinRequests: [CommunityJoinRequest] = []
    @Published var members: [CommunityMember] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    let communityId: String

    private let memberRepository: CommunityMemberRepository
    private let postRepository: CommunityPostRepository
    private let communityRepository: CommunityRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        communityId: String,
        memberRepository: CommunityMemberRepository = .shared,
        postRepository: CommunityPostRepository = .shared,
        communityRepository: CommunityRepository = .shared
    ) {
        self.communityId = communityId
        self.memberRepository = memberRepository
        self.postRepository = postRepository
        self.communityRepository = communityRepository
        bind()
    }

    private func bind() {
        isLoading = true

        memberRepository.listenReports(communityId: communityId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reports in
                self?.reports = reports
                self?.isLoading = false
            }
            .store(in: &cancellables)

        memberRepository.listenJoinRequests(communityId: communityId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requests in
                self?.pendingJoinRequests = requests
            }
            .store(in: &cancellables)

        communityRepository.listenCommunityMembers(communityId: communityId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] members in
                self?.members = members
            }
            .store(in: &cancellables)
    }

    // MARK: - Reports

    func resolveReport(_ reportId: String, status: CommunityReportStatus, reviewNote: String = "") async {
        do {
            try await memberRepository.resolveReport(reportId: reportId, status: status, reviewNote: reviewNote)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Join requests

    func approveJoinRequest(_ requestId: String) async {
        do {
            try await memberRepository.processJoinRequest(communityId: communityId, requestId: requestId, approve: true)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func rejectJoinRequest(_ requestId: String) async {
        do {
            try await memberRepository.processJoinRequest(communityId: communityId, requestId: requestId, approve: false)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Members

    func banMember(_ userId: String, reason: String) async {
        do {
            try await memberRepository.banMember(communityId: communityId, userId: userId, reason: reason)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func kickMember(_ userId: String) async {
        do {
            try await memberRepository.kickMember(communityId: communityId, userId: userId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateRole(_ userId: String, role: CommunityMemberRole) async {
        do {
            try await memberRepository.updateRole(communityId: communityId, userId: userId, newRole: role)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Promote a member to the next role up the ladder
    /// (MEMBER → MODERATOR → ADMIN). No-op for OWNER. Mirrors Android's
    /// CommunityModerationViewModel.promoteMember — OWNER may grant ADMIN;
    /// the repo gates the actual write server-side too.
    func promoteMember(_ memberId: String, newRole: CommunityMemberRole) async {
        do {
            try await memberRepository.updateRole(communityId: communityId, userId: memberId, newRole: newRole)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Demote a member down the ladder (ADMIN → MODERATOR → MEMBER). The
    /// authorisation check still lives in the repo + Firestore rules; this
    /// is the explicit-intent wrapper so callsites read naturally.
    func demoteMember(_ memberId: String, newRole: CommunityMemberRole) async {
        do {
            try await memberRepository.updateRole(communityId: communityId, userId: memberId, newRole: newRole)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Posts

    func hidePost(_ postId: String) async {
        do {
            try await postRepository.deletePost(communityId: communityId, postId: postId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearError() { error = nil }
}
