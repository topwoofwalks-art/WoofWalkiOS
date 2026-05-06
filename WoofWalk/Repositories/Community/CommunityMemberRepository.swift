import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Combine

/// Member management for communities. Mirrors Android
/// `CommunityMemberRepository` — every multi-doc / authoritative mutation
/// goes through a Cloud Function (region pinned to `europe-west2` to match
/// the deployment), reads are direct Firestore listeners.
final class CommunityMemberRepository {
    static let shared = CommunityMemberRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private lazy var functions = Functions.functions(region: "europe-west2")

    private init() {}

    private var communitiesCollection: CollectionReference {
        db.collection("communities")
    }

    private func membersCollection(_ communityId: String) -> CollectionReference {
        communitiesCollection.document(communityId).collection("members")
    }

    /// camelCase to match the CFs (functions/src/communities/communityCallables.ts:344
    /// uses collectionGroup('joinRequests')). Keeping client+server aligned is
    /// load-bearing — Android lost requests by writing to a different name.
    private func joinRequestsCollection(_ communityId: String) -> CollectionReference {
        communitiesCollection.document(communityId).collection("joinRequests")
    }

    // MARK: - Members

    func listenMembers(communityId: String, limit: Int = 100) -> AnyPublisher<[CommunityMember], Never> {
        let subject = CurrentValueSubject<[CommunityMember], Never>([])
        let listener = membersCollection(communityId)
            .whereField("isBanned", isEqualTo: false)
            .order(by: "joinedAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[MemberRepo] members error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let members = snapshot?.documents.compactMap { doc -> CommunityMember? in
                    var m = doc.decodeCommunityMember()
                    if m?.userId.isEmpty ?? true { m?.userId = doc.documentID }
                    return m
                } ?? []
                subject.send(members)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func getMember(communityId: String, userId: String) async throws -> CommunityMember? {
        let doc = try await membersCollection(communityId).document(userId).getDocument()
        guard doc.exists else { return nil }
        var member = doc.decodeCommunityMember()
        if member?.userId.isEmpty ?? true { member?.userId = doc.documentID }
        return member
    }

    func updateRole(communityId: String, userId: String, newRole: CommunityMemberRole) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        // Caller must be admin (or owner for OWNER transfers).
        let callerDoc = try await membersCollection(communityId).document(currentUserId).getDocument()
        guard let caller = try? callerDoc.data(as: CommunityMember.self) else {
            throw makeError(403, "Not a member")
        }
        guard caller.canAdmin else {
            throw makeError(403, "Not authorized to change roles")
        }
        if newRole == .owner, !caller.isOwner {
            throw makeError(403, "Only the owner can transfer ownership")
        }
        let targetDoc = try await membersCollection(communityId).document(userId).getDocument()
        guard let target = try? targetDoc.data(as: CommunityMember.self) else {
            throw makeError(404, "Target member not found")
        }
        if target.isOwner {
            throw makeError(403, "Cannot change the owner's role")
        }
        try await membersCollection(communityId).document(userId).updateData([
            "role": newRole.rawValue,
            "lastActiveAt": Date().timeIntervalSince1970 * 1000
        ])
    }

    /// Ban a member: keeps the doc but flips `isBanned=true` + records reason.
    /// Banned members are filtered out of every member listener
    /// (`whereField("isBanned", isEqualTo: false)`) so they vanish from UI
    /// without losing the audit trail.
    func banMember(communityId: String, userId: String, reason: String = "") async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let callerDoc = try await membersCollection(communityId).document(currentUserId).getDocument()
        guard let caller = try? callerDoc.data(as: CommunityMember.self) else {
            throw makeError(403, "Not a member")
        }
        guard caller.canModerate else {
            throw makeError(403, "Not authorized to ban members")
        }
        let targetDoc = try await membersCollection(communityId).document(userId).getDocument()
        guard let target = try? targetDoc.data(as: CommunityMember.self) else {
            throw makeError(404, "Target member not found")
        }
        if target.isOwner {
            throw makeError(403, "Cannot ban the owner")
        }
        if caller.role == .moderator, target.canAdmin {
            throw makeError(403, "Moderators cannot ban admins")
        }
        try await membersCollection(communityId).document(userId).updateData([
            "isBanned": true,
            "banReason": reason,
            "lastActiveAt": Date().timeIntervalSince1970 * 1000
        ])
    }

    /// Hard-remove a member from the community. Decrements memberCount via a
    /// transaction. Use `banMember` instead when an audit trail matters.
    func kickMember(communityId: String, userId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let callerDoc = try await membersCollection(communityId).document(currentUserId).getDocument()
        guard let caller = try? callerDoc.data(as: CommunityMember.self) else {
            throw makeError(403, "Not a member")
        }
        guard caller.canModerate else {
            throw makeError(403, "Not authorized to kick members")
        }
        let targetDoc = try await membersCollection(communityId).document(userId).getDocument()
        guard let target = try? targetDoc.data(as: CommunityMember.self) else {
            throw makeError(404, "Target member not found")
        }
        if target.isOwner {
            throw makeError(403, "Cannot kick the owner")
        }
        if caller.role == .moderator, target.canAdmin {
            throw makeError(403, "Moderators cannot kick admins")
        }
        let memberRef = membersCollection(communityId).document(userId)
        let communityRef = communitiesCollection.document(communityId)
        _ = try await db.runTransaction { transaction, _ -> Any? in
            transaction.deleteDocument(memberRef)
            transaction.updateData([
                "memberCount": FieldValue.increment(Int64(-1)),
                "updatedAt": Date().timeIntervalSince1970 * 1000
            ], forDocument: communityRef)
            return nil
        }
    }

    // MARK: - Invitations (CF-backed)

    /// Send an invite via the `sendCommunityInvite` Cloud Function. The CF
    /// validates membership + writes the invite doc + dispatches FCM.
    func inviteMember(communityId: String, inviteeId: String) async throws {
        guard auth.currentUser != nil else {
            throw makeError(401, "User not authenticated")
        }
        let payload: [String: Any] = [
            "communityId": communityId,
            "inviteeId": inviteeId
        ]
        _ = try await functions.httpsCallable("sendCommunityInvite").call(payload)
    }

    // MARK: - Join Requests

    /// Live listener for the pending join requests on this community. Used
    /// by the moderation screen.
    func listenJoinRequests(communityId: String) -> AnyPublisher<[CommunityJoinRequest], Never> {
        let subject = CurrentValueSubject<[CommunityJoinRequest], Never>([])
        let listener = joinRequestsCollection(communityId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[MemberRepo] joinRequests error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let requests = snapshot?.documents.compactMap { $0.decodeCommunityJoinRequest() } ?? []
                subject.send(requests)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Create a join request for a private community. Bails if the user is
    /// already a member or has a pending request — both server-side rules
    /// and CF approval handle this, but a quick client check avoids the
    /// confusing duplicate-write error.
    @discardableResult
    func createJoinRequest(communityId: String, message: String = "") async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let currentUserName = auth.currentUser?.displayName ?? "Anonymous"

        let existingMember = try await membersCollection(communityId).document(currentUserId).getDocument()
        if existingMember.exists {
            throw makeError(409, "Already a member of this community")
        }
        let existingRequest = try await joinRequestsCollection(communityId)
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        if !existingRequest.isEmpty {
            throw makeError(409, "Join request already pending")
        }

        let userDoc = try await db.collection("users").document(currentUserId).getDocument()
        let photoUrl = (userDoc.get("photoURL") as? String) ?? auth.currentUser?.photoURL?.absoluteString

        let payload: [String: Any] = [
            "userId": currentUserId,
            "userName": currentUserName,
            "userPhotoUrl": photoUrl ?? "",
            "communityId": communityId,
            "message": message,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]
        let docRef = try await joinRequestsCollection(communityId).addDocument(data: payload)
        return docRef.documentID
    }

    /// Approve or reject a join request via the
    /// `processCommunityJoinRequest` Cloud Function (the CF re-checks admin
    /// role + atomically creates the member doc).
    func processJoinRequest(communityId: String, requestId: String, approve: Bool) async throws {
        let payload: [String: Any] = [
            "communityId": communityId,
            "requestId": requestId,
            "action": approve ? "approve" : "reject"
        ]
        _ = try await functions.httpsCallable("processCommunityJoinRequest").call(payload)
    }

    // MARK: - Moderation reports (CF-backed)

    /// Resolve a community report via the `processCommunityReport` Cloud
    /// Function. Falls back to direct Firestore update if the callable
    /// is unavailable (mirrors Android's resolveReport which does the
    /// direct update path).
    func resolveReport(reportId: String, status: CommunityReportStatus, reviewNote: String = "") async throws {
        guard let reviewer = auth.currentUser else {
            throw makeError(401, "Sign in to resolve reports")
        }
        // Try CF first (canonical path on Android too); fall back to direct
        // write since `processCommunityReport` accepts either.
        do {
            let payload: [String: Any] = [
                "reportId": reportId,
                "status": status.rawValue,
                "reviewNote": reviewNote
            ]
            _ = try await functions.httpsCallable("processCommunityReport").call(payload)
        } catch {
            print("[MemberRepo] processCommunityReport CF failed, falling back to direct write: \(error.localizedDescription)")
            try await db.collection("community_reports").document(reportId).updateData([
                "status": status.rawValue,
                "reviewedByUserId": reviewer.uid,
                "reviewedByUserName": reviewer.displayName ?? "",
                "reviewNote": reviewNote,
                "resolvedAt": Date().timeIntervalSince1970 * 1000
            ])
        }
    }

    func listenReports(communityId: String) -> AnyPublisher<[CommunityReport], Never> {
        let subject = CurrentValueSubject<[CommunityReport], Never>([])
        let listener = db.collection("community_reports")
            .whereField("communityId", isEqualTo: communityId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[MemberRepo] reports error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let reports = snapshot?.documents.compactMap { $0.decodeCommunityReport() } ?? []
                subject.send(reports)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    private func makeError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "CommunityMemberRepository", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
