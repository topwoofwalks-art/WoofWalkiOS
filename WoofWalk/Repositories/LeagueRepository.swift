import Foundation
import FirebaseAuth
import FirebaseFirestore

class LeagueRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    // MARK: - Week ID Helpers

    /// Get the current ISO week identifier, e.g. "2026-W11".
    func currentWeekId() -> String {
        let calendar = Calendar(identifier: .iso8601)
        let now = Date()
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        return "\(year)-W\(String(format: "%02d", week))"
    }

    /// Get the previous ISO week identifier for end-of-week processing.
    func previousWeekId() -> String {
        let calendar = Calendar(identifier: .iso8601)
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        let week = calendar.component(.weekOfYear, from: lastWeek)
        let year = calendar.component(.yearForWeekOfYear, from: lastWeek)
        return "\(year)-W\(String(format: "%02d", week))"
    }

    // MARK: - League Assignment

    /// Ensure the current user is assigned to a league group for this week.
    /// If they already have one, return it. Otherwise, find or create a group.
    /// Returns (weekId, groupId).
    func ensureLeagueAssignment() async throws -> (String, String) {
        guard let userId = auth.currentUser?.uid else {
            throw LeagueError.notAuthenticated
        }
        let weekId = currentWeekId()

        // Check if user already has a group for this week
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userData = userDoc.data() ?? [:]
        let currentWeek = userData["leagueWeekId"] as? String
        let currentGroupId = userData["leagueGroupId"] as? String

        if currentWeek == weekId, let groupId = currentGroupId {
            // Already assigned this week
            return (weekId, groupId)
        }

        // Determine the user's tier
        let tierStr = userData["leagueTier"] as? String ?? LeagueTier.bronze.rawValue
        let tier = LeagueTier(rawValue: tierStr) ?? .bronze

        // Look for an open group in this tier for this week
        let groupsRef = db.collection("leagues").document(weekId).collection("groups")
        let openGroups = try await groupsRef
            .whereField("tier", isEqualTo: tier.rawValue)
            .whereField("participantCount", isLessThan: WeeklyLeagueState.maxGroupSize)
            .limit(to: 1)
            .getDocuments()

        let groupId: String
        if let existingGroup = openGroups.documents.first {
            // Join existing group
            groupId = existingGroup.documentID
            try await groupsRef.document(groupId).updateData([
                "participantIds": FieldValue.arrayUnion([userId]),
                "participantCount": FieldValue.increment(Int64(1))
            ])
        } else {
            // Create new group
            let newGroupRef = groupsRef.document()
            groupId = newGroupRef.documentID
            let group: [String: Any] = [
                "tier": tier.rawValue,
                "participantIds": [userId],
                "participantCount": 1,
                "weekId": weekId
            ]
            try await newGroupRef.setData(group)
        }

        // Create score entry for the user
        let displayName = userData["username"] as? String
            ?? userData["displayName"] as? String
            ?? "Walker"
        let photoUrl = userData["photoUrl"] as? String
        var scoreData: [String: Any] = [
            "weeklyPoints": Int64(0),
            "displayName": displayName
        ]
        if let photoUrl = photoUrl {
            scoreData["photoUrl"] = photoUrl
        }
        try await groupsRef.document(groupId).collection("scores").document(userId)
            .setData(scoreData)

        // Update user document with current week assignment
        try await db.collection("users").document(userId).updateData([
            "leagueWeekId": weekId,
            "leagueGroupId": groupId,
            "leagueTier": tier.rawValue
        ])

        return (weekId, groupId)
    }

    // MARK: - Weekly Points

    /// Add points to the user's weekly league score.
    /// Called after a walk is completed and paw points are awarded.
    /// Ensures league assignment first, then increments the score.
    func addWeeklyPoints(_ points: Int) async throws {
        guard let userId = auth.currentUser?.uid else { return }

        // Ensure assignment first (creates group/score if needed)
        let (weekId, groupId) = try await ensureLeagueAssignment()

        try await db.collection("leagues").document(weekId)
            .collection("groups").document(groupId)
            .collection("scores").document(userId)
            .updateData([
                "weeklyPoints": FieldValue.increment(Int64(points))
            ])
    }

    // MARK: - End-of-Week Processing

    /// Process end-of-week promotions/demotions.
    /// Called lazily when the user opens the league screen in a new week.
    /// Returns the user's new tier after processing.
    @discardableResult
    func processWeekEnd(previousWeekId: String) async throws -> LeagueTier {
        guard let userId = auth.currentUser?.uid else {
            return .bronze
        }

        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userData = userDoc.data() ?? [:]
        guard let groupId = userData["leagueGroupId"] as? String else {
            return LeagueTier(rawValue: userData["leagueTier"] as? String ?? "") ?? .bronze
        }
        let currentTier = LeagueTier(rawValue: userData["leagueTier"] as? String ?? "") ?? .bronze

        // Get the scores from the previous week's group
        let scores = try await db.collection("leagues").document(previousWeekId)
            .collection("groups").document(groupId)
            .collection("scores")
            .order(by: "weeklyPoints", descending: true)
            .getDocuments()

        let totalParticipants = scores.documents.count
        guard let userIndex = scores.documents.firstIndex(where: { $0.documentID == userId }) else {
            // User wasn't in this group, keep current tier
            return currentTier
        }

        let rank = userIndex + 1
        let newTier: LeagueTier
        if rank <= WeeklyLeagueState.promotionCutoff {
            newTier = currentTier.promote()
        } else if rank > totalParticipants - WeeklyLeagueState.demotionCutoff {
            newTier = currentTier.demote()
        } else {
            newTier = currentTier
        }

        if newTier != currentTier {
            try await db.collection("users").document(userId)
                .updateData(["leagueTier": newTier.rawValue])
        }

        return newTier
    }

    // MARK: - Read Current State

    /// Get the current league state including all participants in the user's group.
    /// Triggers league assignment and end-of-week processing if needed.
    func getCurrentLeagueState() async throws -> WeeklyLeagueState? {
        guard let uid = auth.currentUser?.uid else { return nil }

        // Check if we need to process previous week
        let userDocBefore = try await db.collection("users").document(uid).getDocument()
        let prevWeek = userDocBefore.data()?["leagueWeekId"] as? String
        let currentWeek = currentWeekId()
        if let prevWeek = prevWeek, prevWeek != currentWeek {
            // Previous week needs processing before assignment
            try await processWeekEnd(previousWeekId: prevWeek)
        }

        // Ensure assignment for current week
        let (weekId, groupId) = try await ensureLeagueAssignment()

        let userDoc = try await db.collection("users").document(uid).getDocument()
        let tierStr = userDoc.data()?["leagueTier"] as? String ?? LeagueTier.bronze.rawValue
        let tier = LeagueTier(rawValue: tierStr) ?? .bronze

        // Read scores from the correct path: leagues/{weekId}/groups/{groupId}/scores
        let snapshot = try await db.collection("leagues").document(weekId)
            .collection("groups").document(groupId)
            .collection("scores")
            .order(by: "weeklyPoints", descending: true)
            .getDocuments()

        var participants: [RankedParticipant] = []
        for (index, doc) in snapshot.documents.enumerated() {
            let data = doc.data()
            participants.append(RankedParticipant(
                userId: doc.documentID,
                displayName: data["displayName"] as? String ?? "Walker",
                photoUrl: data["photoUrl"] as? String,
                weeklyPoints: data["weeklyPoints"] as? Int64 ?? 0,
                rank: index + 1
            ))
        }

        return WeeklyLeagueState(
            weekId: weekId,
            tier: tier,
            groupId: groupId,
            participants: participants,
            currentUserId: uid
        )
    }

    /// Get the user's current league tier.
    func getCurrentTier() async -> LeagueTier {
        guard let userId = auth.currentUser?.uid else { return .bronze }
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            return LeagueTier(rawValue: doc.data()?["leagueTier"] as? String ?? "") ?? .bronze
        } catch {
            return .bronze
        }
    }
}

// MARK: - Errors

enum LeagueError: Error, LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User not authenticated"
        }
    }
}
