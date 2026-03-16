import SwiftUI

enum AppRoute: Hashable {
    // Existing
    case map
    case profile
    case settings
    case walkHistory
    case stats
    case editProfile
    case leaderboard

    // Walk
    case walkCompletion(distance: Double, duration: Int)
    case walkDetail(walkId: String)

    // Dog
    case dogStats(dogId: String)
    case addDog
    case editDog(dogId: String)

    // Social
    case socialHub
    case feed
    case postDetail(postId: String)
    case createPost

    // Gamification
    case challenges
    case challengeDetail(challengeId: String)
    case league
    case streaks

    // Discovery
    case discovery
    case providerDetail(providerId: String)

    // Notifications
    case notifications

    // Charity
    case charitySettings

    // Chat
    case chatList
    case chatDetail(chatId: String)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .map: hasher.combine("map")
        case .profile: hasher.combine("profile")
        case .settings: hasher.combine("settings")
        case .walkHistory: hasher.combine("walkHistory")
        case .stats: hasher.combine("stats")
        case .editProfile: hasher.combine("editProfile")
        case .leaderboard: hasher.combine("leaderboard")
        case .walkCompletion(let d, let dur): hasher.combine("walkCompletion"); hasher.combine(d); hasher.combine(dur)
        case .walkDetail(let id): hasher.combine("walkDetail"); hasher.combine(id)
        case .dogStats(let id): hasher.combine("dogStats"); hasher.combine(id)
        case .addDog: hasher.combine("addDog")
        case .editDog(let id): hasher.combine("editDog"); hasher.combine(id)
        case .socialHub: hasher.combine("socialHub")
        case .feed: hasher.combine("feed")
        case .postDetail(let id): hasher.combine("postDetail"); hasher.combine(id)
        case .createPost: hasher.combine("createPost")
        case .challenges: hasher.combine("challenges")
        case .challengeDetail(let id): hasher.combine("challengeDetail"); hasher.combine(id)
        case .league: hasher.combine("league")
        case .streaks: hasher.combine("streaks")
        case .discovery: hasher.combine("discovery")
        case .providerDetail(let id): hasher.combine("providerDetail"); hasher.combine(id)
        case .notifications: hasher.combine("notifications")
        case .charitySettings: hasher.combine("charitySettings")
        case .chatList: hasher.combine("chatList")
        case .chatDetail(let id): hasher.combine("chatDetail"); hasher.combine(id)
        }
    }

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}
