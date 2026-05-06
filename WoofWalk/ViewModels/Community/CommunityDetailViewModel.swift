import Foundation
import FirebaseAuth
import Combine

/// Tabs on the community detail screen. Order matches Android's
/// `CommunityDetailScreen` tabs: Feed / Events / Chat / Members. The
/// type-specific tab is rendered conditionally per community type.
enum CommunityDetailTab: Int, CaseIterable, Identifiable {
    case feed
    case events
    case chat
    case members
    case typeSpecific

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .feed: return "Feed"
        case .events: return "Events"
        case .chat: return "Chat"
        case .members: return "Members"
        case .typeSpecific: return "Featured"
        }
    }

    var iconSystemName: String {
        switch self {
        case .feed: return "newspaper"
        case .events: return "calendar"
        case .chat: return "bubble.left.and.bubble.right"
        case .members: return "person.3"
        case .typeSpecific: return "star"
        }
    }
}

/// Drives `CommunityDetailScreen`. Holds live state for the community doc
/// + members + posts (split into pinned/regular) + events + chat. Mirrors
/// Android's `CommunityDetailViewModel` 1:1 — including the auto-join
/// behaviour on createPost (server-side rules require membership).
@MainActor
final class CommunityDetailViewModel: ObservableObject {
    @Published var community: Community?
    @Published var members: [CommunityMember] = []
    @Published var posts: [CommunityPost] = []
    @Published var pinnedPosts: [CommunityPost] = []
    @Published var typeSpecificPosts: [CommunityPost] = []
    @Published var events: [CommunityEvent] = []
    @Published var chatMessages: [CommunityChatMessage] = []
    @Published var currentMember: CommunityMember?
    @Published var isMember: Bool = false
    @Published var myRole: CommunityMemberRole?
    @Published var selectedTab: CommunityDetailTab = .feed
    @Published var isLoading: Bool = false
    @Published var error: String?

    let communityId: String
    let currentUserId: String?

    private let communityRepository: CommunityRepository
    private let postRepository: CommunityPostRepository
    private let memberRepository: CommunityMemberRepository
    private let auth = Auth.auth()
    private var cancellables = Set<AnyCancellable>()

    init(
        communityId: String,
        communityRepository: CommunityRepository = .shared,
        postRepository: CommunityPostRepository = .shared,
        memberRepository: CommunityMemberRepository = .shared
    ) {
        self.communityId = communityId
        self.communityRepository = communityRepository
        self.postRepository = postRepository
        self.memberRepository = memberRepository
        self.currentUserId = Auth.auth().currentUser?.uid
        bind()
        Task { await checkMembership() }
    }

    private func bind() {
        isLoading = true

        communityRepository.listenCommunity(id: communityId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] community in
                self?.community = community
                self?.isLoading = false
                self?.recomputeTypeSpecific()
            }
            .store(in: &cancellables)

        communityRepository.listenCommunityMembers(communityId: communityId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] members in
                self?.members = members
                if let uid = self?.currentUserId,
                   let me = members.first(where: { $0.userId == uid }) {
                    self?.currentMember = me
                    self?.isMember = true
                    self?.myRole = me.role
                } else {
                    self?.currentMember = nil
                    self?.isMember = false
                    self?.myRole = nil
                }
            }
            .store(in: &cancellables)

        postRepository.listenPosts(communityId: communityId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] all in
                guard let self else { return }
                self.pinnedPosts = all.filter { $0.isPinned }
                self.posts = all.filter { !$0.isPinned }
                self.recomputeTypeSpecific(allPosts: all)
            }
            .store(in: &cancellables)

        communityRepository.listenCommunityEvents(communityId: communityId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] events in
                self?.events = events
            }
            .store(in: &cancellables)

        communityRepository.listenCommunityChat(communityId: communityId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.chatMessages = messages
            }
            .store(in: &cancellables)
    }

    private func checkMembership() async {
        guard let userId = currentUserId else { return }
        do {
            let role = try await communityRepository.getMemberRole(communityId: communityId, userId: userId)
            self.myRole = role
            self.isMember = role != nil
        } catch {
            print("[CommunityDetailVM] checkMembership: \(error.localizedDescription)")
        }
    }

    /// Type-specific tab content. Filters posts by the post types relevant
    /// to the community type — same matrix as Android's
    /// CommunityDetailViewModel.filterTypeSpecificPosts.
    private func recomputeTypeSpecific(allPosts: [CommunityPost]? = nil) {
        let source = allPosts ?? (pinnedPosts + posts)
        guard let communityType = community?.type else {
            typeSpecificPosts = []
            return
        }
        let relevantTypes: [CommunityPostType]
        switch communityType {
        case .rescueRehoming: relevantTypes = [.adoptionListing]
        case .puppyParents: relevantTypes = [.puppyMilestone]
        case .trainingBehaviour: relevantTypes = [.trainingTip]
        case .dogSports: relevantTypes = [.competitionEntry]
        case .healthNutrition: relevantTypes = [.dietPlan]
        case .dogFriendlyTravel: relevantTypes = [.destinationReview]
        case .breedSpecific: relevantTypes = [.breedAlert]
        case .localNeighbourhood: relevantTypes = [.walkSchedule]
        case .seniorDogs: relevantTypes = [.dietPlan, .trainingTip]
        case .general: relevantTypes = []
        }
        typeSpecificPosts = relevantTypes.isEmpty ? [] : source.filter { relevantTypes.contains($0.type) }
    }

    /// True when the community has a meaningful type-specific tab worth
    /// rendering. General communities have nothing extra.
    var hasTypeSpecificTab: Bool {
        guard let type = community?.type else { return false }
        return type != .general
    }

    var typeSpecificTabTitle: String {
        guard let type = community?.type else { return "Featured" }
        switch type {
        case .rescueRehoming: return "Adoptions"
        case .puppyParents: return "Milestones"
        case .trainingBehaviour: return "Tips"
        case .dogSports: return "Competitions"
        case .healthNutrition: return "Diet Plans"
        case .dogFriendlyTravel: return "Reviews"
        case .breedSpecific: return "Alerts"
        case .localNeighbourhood: return "Walks"
        case .seniorDogs: return "Wellness"
        case .general: return "Featured"
        }
    }

    // MARK: - Join / Leave

    func joinCommunity() async {
        guard let community else { return }
        if community.privacy == .private {
            // Private — file a join request via the moderation pipeline.
            do {
                _ = try await memberRepository.createJoinRequest(communityId: communityId)
            } catch {
                self.error = error.localizedDescription
            }
            return
        }
        if community.privacy == .inviteOnly {
            self.error = "This community is invite-only."
            return
        }
        do {
            try await communityRepository.joinCommunity(communityId: communityId)
            isMember = true
            myRole = .member
        } catch {
            self.error = error.localizedDescription
        }
    }

    func leaveCommunity() async {
        do {
            try await communityRepository.leaveCommunity(communityId: communityId)
            isMember = false
            myRole = nil
            currentMember = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Posts

    /// Toggle the LIKE reaction on a post (the heart-icon in the feed cell).
    /// `CommunityPostDetailScreen` uses `togglePostReaction(:type)` for the
    /// emoji bar.
    func togglePostLike(_ postId: String) async {
        do {
            try await postRepository.toggleReaction(communityId: communityId, postId: postId, reactionType: "LIKE")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePostReaction(_ postId: String, type: CommunityReactionType) async {
        do {
            try await postRepository.toggleReaction(communityId: communityId, postId: postId, reactionType: type.rawValue)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePostBookmark(_ postId: String) async {
        do {
            try await postRepository.toggleBookmark(communityId: communityId, postId: postId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePin(_ postId: String) async {
        do {
            try await postRepository.togglePin(communityId: communityId, postId: postId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deletePost(_ postId: String) async {
        do {
            try await postRepository.deletePost(communityId: communityId, postId: postId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Auto-join + create. Mirrors Android's CommunityDetailViewModel.createPost.
    /// Auto-joining the community first is intentional — gating the FAB
    /// behind a separate Join click is friction users won't tolerate.
    func createPost(
        type: CommunityPostType,
        title: String,
        content: String,
        mediaData: [Data] = [],
        pollOptions: [PollOption] = [],
        pollEndTime: Double? = nil,
        metadata: [String: String]? = nil
    ) async {
        guard let uid = currentUserId else {
            self.error = "Sign in to post"
            return
        }
        if !isMember {
            do {
                try await communityRepository.joinCommunity(communityId: communityId)
                isMember = true
                myRole = .member
            } catch {
                self.error = "Couldn't join: \(error.localizedDescription)"
                return
            }
        }
        var post = CommunityPost(
            communityId: communityId,
            authorId: uid,
            type: type,
            title: title,
            content: content
        )
        post.pollOptions = pollOptions
        post.pollEndTime = pollEndTime
        post.metadata = metadata
        do {
            _ = try await postRepository.createPost(post, mediaData: mediaData)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Events

    func toggleEventAttendance(_ eventId: String) async {
        do {
            try await communityRepository.toggleEventAttendance(communityId: communityId, eventId: eventId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Chat

    /// Send chat. Throws — caller (CommunityChatTab) shows snackbar+retry.
    func sendChatMessage(_ text: String) async throws -> String {
        try await communityRepository.sendChatMessage(communityId: communityId, text: text)
    }

    // MARK: - Members (admin actions)

    func updateMemberRole(_ userId: String, role: CommunityMemberRole) async {
        do {
            try await memberRepository.updateRole(communityId: communityId, userId: userId, newRole: role)
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

    func banMember(_ userId: String, reason: String) async {
        do {
            try await memberRepository.banMember(communityId: communityId, userId: userId, reason: reason)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func inviteMember(_ inviteeId: String) async {
        do {
            try await memberRepository.inviteMember(communityId: communityId, inviteeId: inviteeId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Settings

    func uploadCoverPhoto(imageData: Data) async {
        do {
            _ = try await communityRepository.uploadCoverPhoto(communityId: communityId, imageData: imageData)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func archiveCommunity() async {
        do {
            try await communityRepository.archiveCommunity(communityId: communityId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteCommunity() async {
        do {
            try await communityRepository.deleteCommunity(communityId: communityId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearError() { error = nil }
}
