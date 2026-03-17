import SwiftUI

enum AppRoute: Hashable {
    // Core
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
    case liveShare(walkId: String)
    case walkPhotoGallery(walkId: String)

    // Dog
    case dogStats(dogId: String)
    case addDog
    case editDog(dogId: String)

    // Social
    case socialHub
    case feed
    case postDetail(postId: String)
    case createPost
    case createStory
    case storyViewer(userId: String)
    case publicProfile(userId: String)
    case followList(userId: String, type: String)
    case reportPost(postId: String)

    // Gamification
    case challenges
    case challengeDetail(challengeId: String)
    case league
    case streaks
    case badgeGallery
    case badgeDetail(badgeId: String)
    case walkHistoryDetail(walkId: String)
    case milestones
    case levelUp

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

    // Business
    case businessInbox
    case businessDashboard
    case businessSchedule
    case businessClients
    case businessEarnings
    case businessSettings

    // Client
    case clientBookings
    case clientDashboard
    case clientInvoices
    case clientMessages

    // Map features
    case hazardReport
    case hazardDetail(hazardId: String)
    case trailConditionReport
    case offLeadZones
    case rainModeSettings
    case routeLibrary
    case routeDetail(routeId: String)
    case nearbyPubs
    case pubDetail(pubId: String)

    // Settings
    case languageSettings
    case autoReplySettings
    case notificationSettings
    case privacySettings

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
        case .liveShare(let id): hasher.combine("liveShare"); hasher.combine(id)
        case .walkPhotoGallery(let id): hasher.combine("walkPhotoGallery"); hasher.combine(id)
        case .dogStats(let id): hasher.combine("dogStats"); hasher.combine(id)
        case .addDog: hasher.combine("addDog")
        case .editDog(let id): hasher.combine("editDog"); hasher.combine(id)
        case .socialHub: hasher.combine("socialHub")
        case .feed: hasher.combine("feed")
        case .postDetail(let id): hasher.combine("postDetail"); hasher.combine(id)
        case .createPost: hasher.combine("createPost")
        case .createStory: hasher.combine("createStory")
        case .storyViewer(let id): hasher.combine("storyViewer"); hasher.combine(id)
        case .publicProfile(let id): hasher.combine("publicProfile"); hasher.combine(id)
        case .followList(let id, let type): hasher.combine("followList"); hasher.combine(id); hasher.combine(type)
        case .reportPost(let id): hasher.combine("reportPost"); hasher.combine(id)
        case .challenges: hasher.combine("challenges")
        case .challengeDetail(let id): hasher.combine("challengeDetail"); hasher.combine(id)
        case .league: hasher.combine("league")
        case .streaks: hasher.combine("streaks")
        case .badgeGallery: hasher.combine("badgeGallery")
        case .badgeDetail(let id): hasher.combine("badgeDetail"); hasher.combine(id)
        case .walkHistoryDetail(let id): hasher.combine("walkHistoryDetail"); hasher.combine(id)
        case .milestones: hasher.combine("milestones")
        case .levelUp: hasher.combine("levelUp")
        case .discovery: hasher.combine("discovery")
        case .providerDetail(let id): hasher.combine("providerDetail"); hasher.combine(id)
        case .notifications: hasher.combine("notifications")
        case .charitySettings: hasher.combine("charitySettings")
        case .chatList: hasher.combine("chatList")
        case .chatDetail(let id): hasher.combine("chatDetail"); hasher.combine(id)
        case .businessInbox: hasher.combine("businessInbox")
        case .businessDashboard: hasher.combine("businessDashboard")
        case .businessSchedule: hasher.combine("businessSchedule")
        case .businessClients: hasher.combine("businessClients")
        case .businessEarnings: hasher.combine("businessEarnings")
        case .businessSettings: hasher.combine("businessSettings")
        case .clientBookings: hasher.combine("clientBookings")
        case .clientDashboard: hasher.combine("clientDashboard")
        case .clientInvoices: hasher.combine("clientInvoices")
        case .clientMessages: hasher.combine("clientMessages")
        case .hazardReport: hasher.combine("hazardReport")
        case .hazardDetail(let id): hasher.combine("hazardDetail"); hasher.combine(id)
        case .trailConditionReport: hasher.combine("trailConditionReport")
        case .offLeadZones: hasher.combine("offLeadZones")
        case .rainModeSettings: hasher.combine("rainModeSettings")
        case .routeLibrary: hasher.combine("routeLibrary")
        case .routeDetail(let id): hasher.combine("routeDetail"); hasher.combine(id)
        case .nearbyPubs: hasher.combine("nearbyPubs")
        case .pubDetail(let id): hasher.combine("pubDetail"); hasher.combine(id)
        case .languageSettings: hasher.combine("languageSettings")
        case .autoReplySettings: hasher.combine("autoReplySettings")
        case .notificationSettings: hasher.combine("notificationSettings")
        case .privacySettings: hasher.combine("privacySettings")
        }
    }

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}
