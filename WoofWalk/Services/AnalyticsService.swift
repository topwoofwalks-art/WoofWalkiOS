import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    func logEvent(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)

        #if DEBUG
        print("[Analytics] \(event.name): \(event.parameters ?? [:])")
        #endif
    }

    func logScreenView(_ screenName: String, screenClass: String? = nil) {
        var parameters: [String: Any] = [
            AnalyticsParameterScreenName: screenName
        ]

        if let screenClass = screenClass {
            parameters[AnalyticsParameterScreenClass] = screenClass
        }

        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)

        #if DEBUG
        print("[Analytics] Screen View: \(screenName)")
        #endif
    }

    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
        Crashlytics.crashlytics().setUserID(userId ?? "")
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func logUserAction(_ action: UserAction) {
        logEvent(action.toAnalyticsEvent())
    }

    func logWalkEvent(_ walkEvent: WalkEvent) {
        logEvent(walkEvent.toAnalyticsEvent())
    }

    func logSocialEvent(_ socialEvent: SocialEvent) {
        logEvent(socialEvent.toAnalyticsEvent())
    }

    func logPOIEvent(_ poiEvent: POIEvent) {
        logEvent(poiEvent.toAnalyticsEvent())
    }
}

struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]?

    init(name: String, parameters: [String: Any]? = nil) {
        self.name = name
        self.parameters = parameters
    }
}

enum UserAction {
    case login(method: String)
    case logout
    case signUp(method: String)
    case profileUpdate
    case settingsChange(setting: String)

    func toAnalyticsEvent() -> AnalyticsEvent {
        switch self {
        case .login(let method):
            return AnalyticsEvent(
                name: AnalyticsEventLogin,
                parameters: [AnalyticsParameterMethod: method]
            )
        case .logout:
            return AnalyticsEvent(name: "logout")
        case .signUp(let method):
            return AnalyticsEvent(
                name: AnalyticsEventSignUp,
                parameters: [AnalyticsParameterMethod: method]
            )
        case .profileUpdate:
            return AnalyticsEvent(name: "profile_update")
        case .settingsChange(let setting):
            return AnalyticsEvent(
                name: "settings_change",
                parameters: ["setting_name": setting]
            )
        }
    }
}

enum WalkEvent {
    case walkStarted(dogCount: Int)
    case walkPaused(distance: Double, duration: Int)
    case walkResumed
    case walkCompleted(distance: Double, duration: Int, dogCount: Int, points: Int)
    case walkCancelled(distance: Double, duration: Int)
    case routeFollowed(routeId: String)
    case guidanceEnabled
    case guidanceDisabled

    func toAnalyticsEvent() -> AnalyticsEvent {
        switch self {
        case .walkStarted(let dogCount):
            return AnalyticsEvent(
                name: "walk_started",
                parameters: ["dog_count": dogCount]
            )
        case .walkPaused(let distance, let duration):
            return AnalyticsEvent(
                name: "walk_paused",
                parameters: [
                    "distance_meters": distance,
                    "duration_seconds": duration
                ]
            )
        case .walkResumed:
            return AnalyticsEvent(name: "walk_resumed")
        case .walkCompleted(let distance, let duration, let dogCount, let points):
            return AnalyticsEvent(
                name: "walk_completed",
                parameters: [
                    "distance_meters": distance,
                    "duration_seconds": duration,
                    "dog_count": dogCount,
                    "points_earned": points,
                    AnalyticsParameterValue: points
                ]
            )
        case .walkCancelled(let distance, let duration):
            return AnalyticsEvent(
                name: "walk_cancelled",
                parameters: [
                    "distance_meters": distance,
                    "duration_seconds": duration
                ]
            )
        case .routeFollowed(let routeId):
            return AnalyticsEvent(
                name: "route_followed",
                parameters: ["route_id": routeId]
            )
        case .guidanceEnabled:
            return AnalyticsEvent(name: "guidance_enabled")
        case .guidanceDisabled:
            return AnalyticsEvent(name: "guidance_disabled")
        }
    }
}

enum SocialEvent {
    case friendAdded
    case friendRemoved
    case messagesSent(count: Int)
    case postCreated(type: String)
    case postLiked
    case postShared
    case eventCreated(attendees: Int)
    case eventJoined

    func toAnalyticsEvent() -> AnalyticsEvent {
        switch self {
        case .friendAdded:
            return AnalyticsEvent(name: "friend_added")
        case .friendRemoved:
            return AnalyticsEvent(name: "friend_removed")
        case .messagesSent(let count):
            return AnalyticsEvent(
                name: "messages_sent",
                parameters: ["message_count": count]
            )
        case .postCreated(let type):
            return AnalyticsEvent(
                name: AnalyticsEventPostScore,
                parameters: ["post_type": type]
            )
        case .postLiked:
            return AnalyticsEvent(name: "post_liked")
        case .postShared:
            return AnalyticsEvent(name: AnalyticsEventShare)
        case .eventCreated(let attendees):
            return AnalyticsEvent(
                name: "event_created",
                parameters: ["expected_attendees": attendees]
            )
        case .eventJoined:
            return AnalyticsEvent(name: "event_joined")
        }
    }
}

enum POIEvent {
    case poiCreated(type: String, hasPhoto: Bool)
    case poiViewed(poiId: String, type: String)
    case poiUpdated(poiId: String)
    case poiVoted(poiId: String, voteType: String)
    case poiReported(poiId: String, reason: String)
    case hazardReported(severity: String)

    func toAnalyticsEvent() -> AnalyticsEvent {
        switch self {
        case .poiCreated(let type, let hasPhoto):
            return AnalyticsEvent(
                name: "poi_created",
                parameters: [
                    "poi_type": type,
                    "has_photo": hasPhoto
                ]
            )
        case .poiViewed(let poiId, let type):
            return AnalyticsEvent(
                name: AnalyticsEventViewItem,
                parameters: [
                    AnalyticsParameterItemID: poiId,
                    "poi_type": type
                ]
            )
        case .poiUpdated(let poiId):
            return AnalyticsEvent(
                name: "poi_updated",
                parameters: [AnalyticsParameterItemID: poiId]
            )
        case .poiVoted(let poiId, let voteType):
            return AnalyticsEvent(
                name: "poi_voted",
                parameters: [
                    AnalyticsParameterItemID: poiId,
                    "vote_type": voteType
                ]
            )
        case .poiReported(let poiId, let reason):
            return AnalyticsEvent(
                name: "poi_reported",
                parameters: [
                    AnalyticsParameterItemID: poiId,
                    "report_reason": reason
                ]
            )
        case .hazardReported(let severity):
            return AnalyticsEvent(
                name: "hazard_reported",
                parameters: ["severity": severity]
            )
        }
    }
}

extension AnalyticsService {
    func logError(_ error: Error, context: String? = nil) {
        var userInfo: [String: Any] = [
            "error_description": error.localizedDescription
        ]

        if let context = context {
            userInfo["context"] = context
        }

        Crashlytics.crashlytics().record(error: error)

        logEvent(AnalyticsEvent(
            name: "error_occurred",
            parameters: userInfo
        ))

        #if DEBUG
        print("[Analytics] Error: \(error.localizedDescription) Context: \(context ?? "none")")
        #endif
    }

    func logPerformance(operation: String, duration: TimeInterval) {
        logEvent(AnalyticsEvent(
            name: "performance_metric",
            parameters: [
                "operation": operation,
                "duration_ms": Int(duration * 1000)
            ]
        ))
    }

    func setCustomDimensions(dogCount: Int, isPremium: Bool) {
        setUserProperty(String(dogCount), forName: "dog_count")
        setUserProperty(isPremium ? "premium" : "free", forName: "user_tier")
    }
}

extension AnalyticsService {
    func logAchievementUnlocked(achievementId: String, achievementName: String) {
        logEvent(AnalyticsEvent(
            name: AnalyticsEventUnlockAchievement,
            parameters: [
                AnalyticsParameterAchievementID: achievementId,
                "achievement_name": achievementName
            ]
        ))
    }

    func logLevelUp(level: Int, points: Int) {
        logEvent(AnalyticsEvent(
            name: AnalyticsEventLevelUp,
            parameters: [
                AnalyticsParameterLevel: level,
                "total_points": points
            ]
        ))
    }

    func logSearchQuery(query: String, resultCount: Int) {
        logEvent(AnalyticsEvent(
            name: AnalyticsEventSearch,
            parameters: [
                AnalyticsParameterSearchTerm: query,
                "result_count": resultCount
            ]
        ))
    }

    func logTutorialComplete(tutorialId: String) {
        logEvent(AnalyticsEvent(
            name: AnalyticsEventTutorialComplete,
            parameters: ["tutorial_id": tutorialId]
        ))
    }

    func logAppRated(rating: Int) {
        logEvent(AnalyticsEvent(
            name: "app_rated",
            parameters: [AnalyticsParameterScore: rating]
        ))
    }
}
