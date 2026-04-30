import Foundation
import FirebaseAuth
import SwiftUI

/// Badge award detection is handled server-side by the `onWalkComplete`
/// and `contributionTriggers` Cloud Functions. The pending-achievement
/// queue is populated by push notifications (badge_earned type) which
/// the app receives and surfaces as WalkAchievement overlays.
///
/// All client-side check methods in this class are stubs — they exist
/// so existing call sites compile, but do nothing. The real badge
/// state lives in `users/{uid}.badges[]` maintained by the CFs.
@MainActor
class BadgeAwardingService: ObservableObject {
    static let shared = BadgeAwardingService()

    @Published var pendingAchievements: [WalkAchievement] = []

    func checkAndAwardBadges(walkDistance: Double, totalWalks: Int, totalDistance: Double, poisCreated: Int, votesGiven: Int) async {
        // No-op: badge detection is owned by server CFs.
    }

    func checkAndAwardBadgesAfterWalk(walkDistance: Double) async {
        // No-op: badge detection is owned by server CFs.
    }

    /// Called by the notification handler when a badge_earned push arrives.
    func enqueueBadgeAchievement(badgeId: String) {
        guard let badge = BadgeDefinitions.getBadge(id: badgeId) else { return }
        let achievement = WalkAchievement(
            id: badge.id,
            title: badge.name,
            description: badge.description,
            icon: badge.iconName,
            color: badge.rarity.color
        )
        pendingAchievements.append(achievement)
    }

    func dismissNextAchievement() {
        if !pendingAchievements.isEmpty {
            pendingAchievements.removeFirst()
        }
    }
}
