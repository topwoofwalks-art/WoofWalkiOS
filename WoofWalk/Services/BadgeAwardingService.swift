import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class BadgeAwardingService: ObservableObject {
    static let shared = BadgeAwardingService()

    @Published var pendingAchievements: [WalkAchievement] = []

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    func checkAndAwardBadges(walkDistance: Double, totalWalks: Int, totalDistance: Double, poisCreated: Int, votesGiven: Int) async {
        guard let uid = auth.currentUser?.uid else { return }

        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let existingBadges = doc.data()?["badges"] as? [String] ?? []

            // Use Firestore totals if available (more accurate than passed-in values)
            let firestoreTotalWalks = doc.data()?["totalWalks"] as? Int ?? totalWalks
            let firestoreTotalDistance = doc.data()?["totalDistanceMeters"] as? Double ?? totalDistance

            var newBadges: [String] = []
            var achievements: [WalkAchievement] = []

            for badge in BadgeDefinitions.allBadges {
                guard !existingBadges.contains(badge.id) else { continue }

                let earned: Bool
                switch badge.unlockCriteria.type {
                case .walksCompleted:
                    earned = firestoreTotalWalks >= badge.unlockCriteria.targetValue
                case .distanceTotal:
                    earned = firestoreTotalDistance >= Double(badge.unlockCriteria.targetValue)
                case .poisCreated:
                    earned = poisCreated >= badge.unlockCriteria.targetValue
                case .votesGiven:
                    earned = votesGiven >= badge.unlockCriteria.targetValue
                case .timeOfDay, .special:
                    earned = false
                }

                if earned {
                    newBadges.append(badge.id)
                    achievements.append(WalkAchievement(
                        id: badge.id,
                        title: badge.name,
                        description: badge.description,
                        icon: badge.iconName,
                        color: badge.rarity.color
                    ))
                }
            }

            if !newBadges.isEmpty {
                try await db.collection("users").document(uid).updateData([
                    "badges": FieldValue.arrayUnion(newBadges)
                ])
                pendingAchievements.append(contentsOf: achievements)
            }
        } catch {
            print("Badge check error: \(error)")
        }
    }

    /// Convenience method that fetches current user stats from Firestore before checking badges.
    /// Call this after a walk completes so badge checks use up-to-date totals.
    func checkAndAwardBadgesAfterWalk(walkDistance: Double) async {
        guard let uid = auth.currentUser?.uid else { return }

        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let totalWalks = doc.data()?["totalWalks"] as? Int ?? 0
            let totalDistance = doc.data()?["totalDistanceMeters"] as? Double ?? 0

            // Count user's POIs
            let poisSnapshot = try await db.collection("pois")
                .whereField("createdBy", isEqualTo: uid)
                .getDocuments()
            let poisCreated = poisSnapshot.documents.count

            await checkAndAwardBadges(
                walkDistance: walkDistance,
                totalWalks: totalWalks,
                totalDistance: totalDistance,
                poisCreated: poisCreated,
                votesGiven: 0
            )
        } catch {
            print("Badge stats fetch error: \(error)")
        }
    }

    func dismissNextAchievement() {
        if !pendingAchievements.isEmpty {
            pendingAchievements.removeFirst()
        }
    }
}
