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
    case globalSearch
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

    // Meet & Greet
    case meetGreetRequest(orgId: String)
    case meetGreetThread(threadId: String)
    case meetGreetClientInbox
    case meetGreetProviderInbox

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
    case businessClientDetail(clientId: String)
    case businessEarnings
    case businessSettings
    case businessWalkConsole(bookingId: String)
    case businessWalkConsoleFull(bookingId: String, dogIds: [String], bookingIds: [String])
    case businessTodaysWalks
    case scanKey

    // Client
    case clientBookings
    case clientBookingDetail(bookingId: String)
    case clientDashboard
    case clientInvoices
    case clientMessages
    case providerSearch(serviceType: String)
    case booking(providerId: String?)

    // Map features
    case hazardReport
    case hazardDetail(hazardId: String)
    case trailConditionReport
    case offLeadZones
    case rainModeSettings
    case plannedWalks
    case routeLibrary
    case routeDetail(routeId: String)
    case nearbyPubs
    case pubDetail(pubId: String)

    // Live Tracking (Professional Services)
    case groomingLive(sessionId: String)
    case careLive(sessionId: String, serviceType: String)
    case daycareLive(sessionId: String)
    case trainingLive(sessionId: String)
    case daycareConsole(bookingId: String, dogIds: [String])
    case trainingSession(sessionId: String)

    // Settings
    case languageSettings
    case autoReplySettings
    case notificationSettings
    case privacySettings

    // Cash-shortage notify flow
    case clientCashRequest(requestId: String)
    case businessCashRequest(requestId: String)

    // Team invitation deeplink (woofwalk://accept-invite?token=...)
    case acceptInvite(token: String)

    // Deep-link parity with Android (MainActivity.parseWoofWalkScheme):
    // hosts that didn't already have an AppRoute case mapped one-to-one
    // to an existing destination. Adding explicit cases keeps the iOS
    // router pure-functional and unit-testable.
    case lostDog(alertId: String)              // woofwalk://lost-dog/{alertId}
    case watchWalk(token: String)              // woofwalk://watch-walk/{token} (Watch Me share)
    case payment(bookingId: String)            // woofwalk://payment/{bookingId}
    case addTip(bookingId: String)             // woofwalk://add_tip/{bookingId} (and `add-tip`)
    case review(bookingId: String)             // woofwalk://review/{bookingId}
    case teamInvite(orgId: String)             // woofwalk://team_invite/{orgId} (and `team-invite`)
    case friendInvite(userId: String)          // woofwalk://friend-invite/{userId} (and `add`/`invite`)
    case stripeConnect                         // woofwalk://stripe_connect
    case oauthCallback                         // woofwalk://oauth
    case communityDetail(communityId: String)  // woofwalk://community/{communityId}
    case communityPost(communityId: String, postId: String) // woofwalk://community/{id}/post/{postId}
    case question(questionId: String)          // woofwalk://q/{questionId} and woofwalk://qa/{id}
    case eventDetail(eventId: String)          // woofwalk://event/{eventId}
    case challengeDeepLink(challengeId: String) // woofwalk://challenge/{challengeId}
    case dogDeepLink(dogId: String)            // woofwalk://dog/{dogId}
    case share(shareToken: String)             // woofwalk://share/{token}
    case providerDeepLink(providerId: String)  // woofwalk://provider/{providerId}
    case charityDeepLink(charityId: String)    // woofwalk://charity/{charityId}
    case settingsSection(section: String)      // woofwalk://settings/{section}
    case referral(code: String)                // woofwalk://referral/{code}

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
        case .globalSearch: hasher.combine("globalSearch")
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
        case .meetGreetRequest(let id): hasher.combine("meetGreetRequest"); hasher.combine(id)
        case .meetGreetThread(let id): hasher.combine("meetGreetThread"); hasher.combine(id)
        case .meetGreetClientInbox: hasher.combine("meetGreetClientInbox")
        case .meetGreetProviderInbox: hasher.combine("meetGreetProviderInbox")
        case .notifications: hasher.combine("notifications")
        case .charitySettings: hasher.combine("charitySettings")
        case .chatList: hasher.combine("chatList")
        case .chatDetail(let id): hasher.combine("chatDetail"); hasher.combine(id)
        case .businessInbox: hasher.combine("businessInbox")
        case .businessDashboard: hasher.combine("businessDashboard")
        case .businessSchedule: hasher.combine("businessSchedule")
        case .businessClients: hasher.combine("businessClients")
        case .businessClientDetail(let id): hasher.combine("businessClientDetail"); hasher.combine(id)
        case .businessEarnings: hasher.combine("businessEarnings")
        case .businessSettings: hasher.combine("businessSettings")
        case .businessWalkConsole(let id): hasher.combine("businessWalkConsole"); hasher.combine(id)
        case .businessWalkConsoleFull(let id, let dogs, let bks): hasher.combine("businessWalkConsoleFull"); hasher.combine(id); hasher.combine(dogs); hasher.combine(bks)
        case .businessTodaysWalks: hasher.combine("businessTodaysWalks")
        case .scanKey: hasher.combine("scanKey")
        case .clientBookings: hasher.combine("clientBookings")
        case .clientBookingDetail(let id): hasher.combine("clientBookingDetail"); hasher.combine(id)
        case .clientDashboard: hasher.combine("clientDashboard")
        case .clientInvoices: hasher.combine("clientInvoices")
        case .clientMessages: hasher.combine("clientMessages")
        case .providerSearch(let type): hasher.combine("providerSearch"); hasher.combine(type)
        case .booking(let id): hasher.combine("booking"); hasher.combine(id)
        case .hazardReport: hasher.combine("hazardReport")
        case .hazardDetail(let id): hasher.combine("hazardDetail"); hasher.combine(id)
        case .trailConditionReport: hasher.combine("trailConditionReport")
        case .offLeadZones: hasher.combine("offLeadZones")
        case .rainModeSettings: hasher.combine("rainModeSettings")
        case .plannedWalks: hasher.combine("plannedWalks")
        case .routeLibrary: hasher.combine("routeLibrary")
        case .routeDetail(let id): hasher.combine("routeDetail"); hasher.combine(id)
        case .nearbyPubs: hasher.combine("nearbyPubs")
        case .pubDetail(let id): hasher.combine("pubDetail"); hasher.combine(id)
        case .groomingLive(let id): hasher.combine("groomingLive"); hasher.combine(id)
        case .careLive(let id, let type): hasher.combine("careLive"); hasher.combine(id); hasher.combine(type)
        case .daycareLive(let id): hasher.combine("daycareLive"); hasher.combine(id)
        case .trainingLive(let id): hasher.combine("trainingLive"); hasher.combine(id)
        case .daycareConsole(let id, let dogIds): hasher.combine("daycareConsole"); hasher.combine(id); hasher.combine(dogIds)
        case .trainingSession(let id): hasher.combine("trainingSession"); hasher.combine(id)
        case .languageSettings: hasher.combine("languageSettings")
        case .autoReplySettings: hasher.combine("autoReplySettings")
        case .notificationSettings: hasher.combine("notificationSettings")
        case .privacySettings: hasher.combine("privacySettings")
        case .clientCashRequest(let id): hasher.combine("clientCashRequest"); hasher.combine(id)
        case .businessCashRequest(let id): hasher.combine("businessCashRequest"); hasher.combine(id)
        case .acceptInvite(let token): hasher.combine("acceptInvite"); hasher.combine(token)
        case .lostDog(let id): hasher.combine("lostDog"); hasher.combine(id)
        case .watchWalk(let token): hasher.combine("watchWalk"); hasher.combine(token)
        case .payment(let id): hasher.combine("payment"); hasher.combine(id)
        case .addTip(let id): hasher.combine("addTip"); hasher.combine(id)
        case .review(let id): hasher.combine("review"); hasher.combine(id)
        case .teamInvite(let id): hasher.combine("teamInvite"); hasher.combine(id)
        case .friendInvite(let id): hasher.combine("friendInvite"); hasher.combine(id)
        case .stripeConnect: hasher.combine("stripeConnect")
        case .oauthCallback: hasher.combine("oauthCallback")
        case .communityDetail(let id): hasher.combine("communityDetail"); hasher.combine(id)
        case .communityPost(let cId, let pId): hasher.combine("communityPost"); hasher.combine(cId); hasher.combine(pId)
        case .question(let id): hasher.combine("question"); hasher.combine(id)
        case .eventDetail(let id): hasher.combine("eventDetail"); hasher.combine(id)
        case .challengeDeepLink(let id): hasher.combine("challengeDeepLink"); hasher.combine(id)
        case .dogDeepLink(let id): hasher.combine("dogDeepLink"); hasher.combine(id)
        case .share(let token): hasher.combine("share"); hasher.combine(token)
        case .providerDeepLink(let id): hasher.combine("providerDeepLink"); hasher.combine(id)
        case .charityDeepLink(let id): hasher.combine("charityDeepLink"); hasher.combine(id)
        case .settingsSection(let s): hasher.combine("settingsSection"); hasher.combine(s)
        case .referral(let c): hasher.combine("referral"); hasher.combine(c)
        }
    }

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}
