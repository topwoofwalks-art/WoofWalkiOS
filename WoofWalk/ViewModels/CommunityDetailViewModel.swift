import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Community Detail Tab

enum CommunityDetailTab: String, CaseIterable, Identifiable {
    case feed = "Feed"
    case events = "Events"
    case chat = "Chat"
    case members = "Members"
    case flagship = "Flagship"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .feed: return "text.bubble"
        case .events: return "calendar"
        case .chat: return "bubble.left.and.bubble.right"
        case .members: return "person.3"
        case .flagship: return "star.fill"
        }
    }
}

@MainActor
class CommunityDetailViewModel: ObservableObject {
    @Published var community: Community?
    @Published var members: [CommunityMember] = []
    @Published var posts: [CommunityPost] = []
    @Published var events: [CommunityEvent] = []
    @Published var isMember = false
    @Published var myRole: CommunityMemberRole?
    @Published var selectedTab: CommunityDetailTab = .feed
    @Published var chatMessages: [ChatMessage] = []
    @Published var messageText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var chatListener: ListenerRegistration?

    // MARK: - Load Community

    func loadCommunity(id: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let document = try await db.collection("communities").document(id).getDocument()
                guard let community = try? document.data(as: Community.self) else {
                    self.errorMessage = "Community not found"
                    self.isLoading = false
                    return
                }

                self.community = community
                self.isLoading = false

                // Check membership in parallel
                await checkMembership(communityId: id)
                loadPosts()
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("[CommunityDetail] Error loading community: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Membership

    private func checkMembership(communityId: String) async {
        guard let uid = auth.currentUser?.uid else {
            isMember = false
            myRole = nil
            return
        }

        do {
            let document = try await db.collection("communities").document(communityId)
                .collection("members").document(uid).getDocument()

            if document.exists, let member = try? document.data(as: CommunityMember.self) {
                self.isMember = !member.isBanned
                self.myRole = member.getMemberRole()
            } else {
                self.isMember = false
                self.myRole = nil
            }
        } catch {
            print("[CommunityDetail] Error checking membership: \(error.localizedDescription)")
            self.isMember = false
            self.myRole = nil
        }
    }

    func joinCommunity() {
        guard let uid = auth.currentUser?.uid,
              let communityId = community?.id else { return }

        Task {
            do {
                // Get user profile for display name
                let userDoc = try await db.collection("users").document(uid).getDocument()
                let displayName = userDoc.data()?["username"] as? String ?? "User"
                let photoUrl = userDoc.data()?["photoUrl"] as? String

                let member = CommunityMember(
                    userId: uid,
                    communityId: communityId,
                    displayName: displayName,
                    photoUrl: photoUrl,
                    role: CommunityMemberRole.MEMBER.rawValue
                )

                try db.collection("communities").document(communityId)
                    .collection("members").document(uid).setData(from: member)

                // Increment member count
                try await db.collection("communities").document(communityId).updateData([
                    "memberCount": FieldValue.increment(Int64(1))
                ])

                self.isMember = true
                self.myRole = .MEMBER

                // Refresh community data
                if var updated = self.community {
                    updated.memberCount += 1
                    self.community = updated
                }
            } catch {
                self.errorMessage = "Failed to join community"
                print("[CommunityDetail] Error joining: \(error.localizedDescription)")
            }
        }
    }

    func leaveCommunity() {
        guard let uid = auth.currentUser?.uid,
              let communityId = community?.id else { return }

        Task {
            do {
                try await db.collection("communities").document(communityId)
                    .collection("members").document(uid).delete()

                try await db.collection("communities").document(communityId).updateData([
                    "memberCount": FieldValue.increment(Int64(-1))
                ])

                self.isMember = false
                self.myRole = nil

                if var updated = self.community {
                    updated.memberCount = max(0, updated.memberCount - 1)
                    self.community = updated
                }
            } catch {
                self.errorMessage = "Failed to leave community"
                print("[CommunityDetail] Error leaving: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Posts

    func loadPosts() {
        guard let communityId = community?.id else { return }

        Task {
            do {
                let snapshot = try await db.collection("communities").document(communityId)
                    .collection("posts")
                    .whereField("isDeleted", isEqualTo: false)
                    .order(by: "isPinned", descending: true)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 30)
                    .getDocuments()

                self.posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            } catch {
                // Fallback without compound ordering
                do {
                    let snapshot = try await db.collection("communities").document(communityId)
                        .collection("posts")
                        .whereField("isDeleted", isEqualTo: false)
                        .limit(to: 30)
                        .getDocuments()

                    self.posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
                        .sorted {
                            if $0.isPinned != $1.isPinned { return $0.isPinned }
                            return $0.createdAt > $1.createdAt
                        }
                } catch {
                    print("[CommunityDetail] Error loading posts: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Members

    func loadMembers() {
        guard let communityId = community?.id else { return }

        Task {
            do {
                let snapshot = try await db.collection("communities").document(communityId)
                    .collection("members")
                    .whereField("isBanned", isEqualTo: false)
                    .limit(to: 50)
                    .getDocuments()

                self.members = snapshot.documents.compactMap { try? $0.data(as: CommunityMember.self) }
                    .sorted { member1, member2 in
                        let roleOrder: [String: Int] = ["OWNER": 0, "ADMIN": 1, "MODERATOR": 2, "MEMBER": 3]
                        return (roleOrder[member1.role] ?? 3) < (roleOrder[member2.role] ?? 3)
                    }
            } catch {
                print("[CommunityDetail] Error loading members: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Events

    func loadEvents() {
        guard let communityId = community?.id else { return }

        Task {
            do {
                let now = Date().timeIntervalSince1970 * 1000
                let snapshot = try await db.collection("communities").document(communityId)
                    .collection("events")
                    .whereField("isCancelled", isEqualTo: false)
                    .limit(to: 20)
                    .getDocuments()

                self.events = snapshot.documents.compactMap { try? $0.data(as: CommunityEvent.self) }
                    .sorted { $0.startTime < $1.startTime }
            } catch {
                print("[CommunityDetail] Error loading events: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Chat

    func loadChat() {
        guard let communityId = community?.id else { return }

        chatListener?.remove()
        chatListener = db.collection("communities").document(communityId)
            .collection("chat")
            .order(by: "createdAt", descending: false)
            .limit(toLast: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("[CommunityDetail] Chat error: \(error.localizedDescription)")
                    return
                }

                self.chatMessages = snapshot?.documents.compactMap { try? $0.data(as: ChatMessage.self) } ?? []
            }
    }

    func sendChatMessage() {
        guard let uid = auth.currentUser?.uid,
              let communityId = community?.id,
              !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = messageText
        messageText = ""

        Task {
            do {
                let userDoc = try await db.collection("users").document(uid).getDocument()
                let senderName = userDoc.data()?["username"] as? String ?? "User"

                let messageData: [String: Any] = [
                    "chatId": communityId,
                    "senderId": uid,
                    "senderName": senderName,
                    "text": text,
                    "readBy": [uid],
                    "isAutoReply": false,
                    "createdAt": FieldValue.serverTimestamp()
                ]

                try await db.collection("communities").document(communityId)
                    .collection("chat").addDocument(data: messageData)
            } catch {
                // Restore message on failure
                self.messageText = text
                print("[CommunityDetail] Error sending message: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Reactions

    func toggleReaction(postId: String, reactionType: String) {
        guard let uid = auth.currentUser?.uid,
              let communityId = community?.id else { return }

        let docRef = db.collection("communities").document(communityId)
            .collection("posts").document(postId)

        Task {
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let post = posts[index]
                if post.likedBy.contains(uid) {
                    try? await docRef.updateData([
                        "likedBy": FieldValue.arrayRemove([uid]),
                        "likeCount": FieldValue.increment(Int64(-1))
                    ])
                } else {
                    try? await docRef.updateData([
                        "likedBy": FieldValue.arrayUnion([uid]),
                        "likeCount": FieldValue.increment(Int64(1))
                    ])
                }
                loadPosts()
            }
        }
    }

    // MARK: - Pin / Report

    func togglePin(postId: String) {
        guard let communityId = community?.id,
              let role = myRole, role.canModerate() else { return }

        Task {
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let newPinned = !posts[index].isPinned
                try? await db.collection("communities").document(communityId)
                    .collection("posts").document(postId)
                    .updateData(["isPinned": newPinned])
                loadPosts()
            }
        }
    }

    func reportContent(postId: String, reason: String) {
        guard let uid = auth.currentUser?.uid,
              let communityId = community?.id else { return }

        Task {
            let reportData: [String: Any] = [
                "reporterId": uid,
                "communityId": communityId,
                "postId": postId,
                "reason": reason,
                "status": "PENDING",
                "createdAt": FieldValue.serverTimestamp()
            ]

            try? await db.collection("reports").addDocument(data: reportData)
        }
    }

    deinit {
        chatListener?.remove()
    }
}
