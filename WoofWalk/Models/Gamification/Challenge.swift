import Foundation
import FirebaseFirestore

enum ChallengeType: String, Codable, CaseIterable {
    case distance = "DISTANCE"
    case walksCount = "WALKS_COUNT"
    case streak = "STREAK"
    case speed = "SPEED"
    case duration = "DURATION"
}

enum ChallengeCategory: String, Codable, CaseIterable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case special = "SPECIAL"
}

struct Challenge: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var type: ChallengeType
    var target: Double
    var unit: String
    var startDate: Timestamp?
    var endDate: Timestamp?
    var participantIds: [String]
    var participantCount: Int
    var iconEmoji: String
    var category: ChallengeCategory
    var isActive: Bool
    var createdBy: String
    @ServerTimestamp var createdAt: Timestamp?

    init(id: String? = nil, title: String = "", description: String = "", type: ChallengeType = .distance, target: Double = 0, unit: String = "km", startDate: Timestamp? = nil, endDate: Timestamp? = nil, participantIds: [String] = [], participantCount: Int = 0, iconEmoji: String = "🎯", category: ChallengeCategory = .weekly, isActive: Bool = true, createdBy: String = "", createdAt: Timestamp? = nil) {
        self.id = id; self.title = title; self.description = description; self.type = type; self.target = target; self.unit = unit; self.startDate = startDate; self.endDate = endDate; self.participantIds = participantIds; self.participantCount = participantCount; self.iconEmoji = iconEmoji; self.category = category; self.isActive = isActive; self.createdBy = createdBy; self.createdAt = createdAt
    }
}

struct ChallengeParticipant: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var userName: String
    var userAvatar: String?
    var progress: Double
    var rank: Int
    var completedAt: Timestamp?
    var joinedAt: Timestamp?

    var isCompleted: Bool { completedAt != nil }

    init(id: String? = nil, userId: String = "", userName: String = "", userAvatar: String? = nil, progress: Double = 0, rank: Int = 0, completedAt: Timestamp? = nil, joinedAt: Timestamp? = nil) {
        self.id = id; self.userId = userId; self.userName = userName; self.userAvatar = userAvatar; self.progress = progress; self.rank = rank; self.completedAt = completedAt; self.joinedAt = joinedAt
    }
}

struct ChallengeLeaderboardEntry: Identifiable {
    var userId: String
    var userName: String
    var userAvatar: String?
    var progress: Double
    var rank: Int
    var isCompleted: Bool

    var id: String { userId }
}
