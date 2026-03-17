import Foundation
import SwiftUI
import FirebaseFirestore

enum LeagueTier: String, Codable, CaseIterable {
    case bronze = "BRONZE"
    case silver = "SILVER"
    case gold = "GOLD"
    case sapphire = "SAPPHIRE"
    case ruby = "RUBY"
    case emerald = "EMERALD"
    case diamond = "DIAMOND"

    var displayName: String { rawValue.capitalized }

    var tierEmoji: String {
        switch self {
        case .bronze: return "\u{1F949}"
        case .silver: return "\u{1F948}"
        case .gold: return "\u{1F947}"
        case .sapphire: return "\u{1F48E}"
        case .ruby: return "\u{2764}\u{FE0F}\u{200D}\u{1F525}"
        case .emerald: return "\u{1F7E2}"
        case .diamond: return "\u{1F48E}"
        }
    }

    var tierGradientColors: [Color] {
        switch self {
        case .bronze: return [Color(hex: 0xCD7F32), Color(hex: 0x8B4513)]
        case .silver: return [Color(hex: 0xC0C0C0), Color(hex: 0x808080)]
        case .gold: return [Color(hex: 0xFFD700), Color(hex: 0xDAA520)]
        case .sapphire: return [Color(hex: 0x0F52BA), Color(hex: 0x082567)]
        case .ruby: return [Color(hex: 0xE0115F), Color(hex: 0x9B111E)]
        case .emerald: return [Color(hex: 0x50C878), Color(hex: 0x006B3C)]
        case .diamond: return [Color(hex: 0xB9F2FF), Color(hex: 0x7EC8E3)]
        }
    }

    var sortOrder: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1
        case .gold: return 2
        case .sapphire: return 3
        case .ruby: return 4
        case .emerald: return 5
        case .diamond: return 6
        }
    }

    func promote() -> LeagueTier {
        switch self {
        case .bronze: return .silver
        case .silver: return .gold
        case .gold: return .sapphire
        case .sapphire: return .ruby
        case .ruby: return .emerald
        case .emerald: return .diamond
        case .diamond: return .diamond
        }
    }

    func demote() -> LeagueTier {
        switch self {
        case .bronze: return .bronze
        case .silver: return .bronze
        case .gold: return .silver
        case .sapphire: return .gold
        case .ruby: return .sapphire
        case .emerald: return .ruby
        case .diamond: return .emerald
        }
    }
}

struct LeagueParticipant: Codable {
    var userId: String
    var displayName: String
    var photoUrl: String?
    var weeklyPoints: Int64

    init(userId: String = "", displayName: String = "", photoUrl: String? = nil, weeklyPoints: Int64 = 0) {
        self.userId = userId; self.displayName = displayName; self.photoUrl = photoUrl; self.weeklyPoints = weeklyPoints
    }
}

struct LeagueGroup: Identifiable, Codable {
    @DocumentID var id: String?
    var tier: String
    var participantIds: [String]
    var weekId: String

    init(id: String? = nil, tier: String = LeagueTier.bronze.rawValue, participantIds: [String] = [], weekId: String = "") {
        self.id = id; self.tier = tier; self.participantIds = participantIds; self.weekId = weekId
    }

    var leagueTier: LeagueTier {
        LeagueTier(rawValue: tier) ?? .bronze
    }
}

struct RankedParticipant: Identifiable, Codable {
    var userId: String
    var displayName: String
    var photoUrl: String?
    var weeklyPoints: Int64
    var rank: Int

    var id: String { userId }

    init(userId: String = "", displayName: String = "", photoUrl: String? = nil, weeklyPoints: Int64 = 0, rank: Int = 0) {
        self.userId = userId; self.displayName = displayName; self.photoUrl = photoUrl; self.weeklyPoints = weeklyPoints; self.rank = rank
    }
}

struct WeeklyLeagueState {
    var weekId: String
    var tier: LeagueTier
    var groupId: String
    var participants: [RankedParticipant]
    var currentUserId: String
    var weekStartMillis: Int64
    var weekEndMillis: Int64

    static let promotionCutoff = 10
    static let demotionCutoff = 5
    static let maxGroupSize = 30

    var currentUserRank: Int? {
        participants.first { $0.userId == currentUserId }?.rank
    }

    var isInPromotionZone: Bool {
        guard let rank = currentUserRank else { return false }
        return rank <= WeeklyLeagueState.promotionCutoff
    }

    var isInDemotionZone: Bool {
        guard let rank = currentUserRank else { return false }
        return rank > participants.count - WeeklyLeagueState.demotionCutoff
    }

    init(weekId: String = "", tier: LeagueTier = .bronze, groupId: String = "", participants: [RankedParticipant] = [], currentUserId: String = "", weekStartMillis: Int64 = 0, weekEndMillis: Int64 = 0) {
        self.weekId = weekId; self.tier = tier; self.groupId = groupId; self.participants = participants; self.currentUserId = currentUserId; self.weekStartMillis = weekStartMillis; self.weekEndMillis = weekEndMillis
    }
}
