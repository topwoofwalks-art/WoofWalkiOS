import Foundation
import FirebaseFirestore

enum CommunityInviteStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case declined = "DECLINED"
    case expired = "EXPIRED"

    static func from(_ raw: String?) -> CommunityInviteStatus {
        guard let raw else { return .pending }
        return CommunityInviteStatus(rawValue: raw.uppercased()) ?? .pending
    }
}

/// Invitation to join a community. Path:
/// `communities/{communityId}/invites/{inviteId}`. Written by
/// the `sendCommunityInvite` Cloud Function so the client never needs to
/// build this struct from scratch — listed here for read-side decoding.
struct CommunityInvite: Identifiable, Codable {
    var id: String?
    var communityId: String = ""
    var communityName: String = ""
    var invitedUserId: String = ""
    var invitedUserName: String = ""
    var invitedByUserId: String = ""
    var invitedByUserName: String = ""
    var status: CommunityInviteStatus = .pending
    var message: String = ""
    var expiresAt: Double?
    var respondedAt: Double?
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    var isPending: Bool { status == .pending }
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date().timeIntervalSince1970 * 1000 > expiresAt
    }
}

/// Request to join a private / invite-only community. Path:
/// `communities/{communityId}/joinRequests/{requestId}` (camelCase, matches
/// the CF — see CommunityMemberRepository.kt:35-36 on Android for why this
/// matters).
struct CommunityJoinRequest: Identifiable, Codable {
    var id: String?
    var communityId: String = ""
    var communityName: String = ""
    var userId: String = ""
    var userName: String = ""
    var userPhotoUrl: String?
    var status: CommunityInviteStatus = .pending
    var message: String = ""
    var reviewedByUserId: String?
    var reviewedByUserName: String?
    var reviewNote: String?
    var respondedAt: Double?
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    var isPending: Bool { status == .pending }
    var isAccepted: Bool { status == .accepted }

    enum CodingKeys: String, CodingKey {
        case id
        case communityId, communityName
        case userId, userName, userPhotoUrl
        case status, message
        case reviewedByUserId, reviewedByUserName, reviewNote
        case respondedAt, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.communityId = (try? c.decode(String.self, forKey: .communityId)) ?? ""
        self.communityName = (try? c.decode(String.self, forKey: .communityName)) ?? ""
        self.userId = (try? c.decode(String.self, forKey: .userId)) ?? ""
        self.userName = (try? c.decode(String.self, forKey: .userName)) ?? ""
        self.userPhotoUrl = try? c.decode(String.self, forKey: .userPhotoUrl)
        if let raw = try? c.decode(String.self, forKey: .status) {
            // CF writes lowercase "pending" — normalise.
            self.status = CommunityInviteStatus.from(raw)
        }
        self.message = (try? c.decode(String.self, forKey: .message)) ?? ""
        self.reviewedByUserId = try? c.decode(String.self, forKey: .reviewedByUserId)
        self.reviewedByUserName = try? c.decode(String.self, forKey: .reviewedByUserName)
        self.reviewNote = try? c.decode(String.self, forKey: .reviewNote)
        self.respondedAt = try? c.decode(Double.self, forKey: .respondedAt)
        if let n = try? c.decode(Double.self, forKey: .createdAt) {
            self.createdAt = n
        } else if let ts = try? c.decode(Timestamp.self, forKey: .createdAt) {
            self.createdAt = ts.dateValue().timeIntervalSince1970 * 1000
        } else {
            self.createdAt = Date().timeIntervalSince1970 * 1000
        }
    }

    init(
        id: String? = nil,
        communityId: String = "",
        communityName: String = "",
        userId: String = "",
        userName: String = "",
        userPhotoUrl: String? = nil,
        status: CommunityInviteStatus = .pending,
        message: String = "",
        reviewedByUserId: String? = nil,
        reviewedByUserName: String? = nil,
        reviewNote: String? = nil,
        respondedAt: Double? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.communityId = communityId
        self.communityName = communityName
        self.userId = userId
        self.userName = userName
        self.userPhotoUrl = userPhotoUrl
        self.status = status
        self.message = message
        self.reviewedByUserId = reviewedByUserId
        self.reviewedByUserName = reviewedByUserName
        self.reviewNote = reviewNote
        self.respondedAt = respondedAt
        self.createdAt = createdAt
    }
}
