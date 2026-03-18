import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Leaderboard entry for charity monthly contributions.
struct CharityLeaderboardEntry: Identifiable {
    let id: String // userId
    let points: Int64
    let charityId: String
    let walkCount: Int64
}

class CharityRepository {
    static let shared = CharityRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    // UserDefaults keys for offline-first reads
    private let charityEnabledKey = "charity_enabled"
    private let selectedCharityKey = "selected_charity_id"

    // MARK: - Charity Profile (Firestore path: users/{uid}/charityProfile/profile)

    /// Load the full charity profile from Firestore subcollection (matches Android path).
    func getCharityProfile() async throws -> CharityProfile? {
        guard let uid = auth.currentUser?.uid else { return nil }
        let doc = try await db.collection("users").document(uid)
            .collection("charityProfile").document("profile")
            .getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return CharityProfile(
            enabled: data["enabled"] as? Bool ?? false,
            selectedCharityId: data["selectedCharityId"] as? String ?? "dogs_trust",
            lifetimePoints: data["lifetimePoints"] as? Int64 ?? 0,
            monthlyPoints: data["monthlyPoints"] as? Int64 ?? 0,
            lastWalkCharityPoints: data["lastWalkCharityPoints"] as? Int64 ?? 0
        )
    }

    // MARK: - Charity Enabled

    /// Read charity enabled from UserDefaults (offline-first, matches Android DataStore pattern).
    func isCharityEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: charityEnabledKey)
    }

    /// Toggle charity enabled in UserDefaults and sync to Firestore.
    func setCharityEnabled(_ enabled: Bool) async throws {
        UserDefaults.standard.set(enabled, forKey: charityEnabledKey)

        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("users").document(uid)
            .collection("charityProfile").document("profile")
            .setData(["enabled": enabled], merge: true)
    }

    // MARK: - Selected Charity

    /// Get selected charity ID from UserDefaults (offline-first).
    func getSelectedCharityId() -> String {
        return UserDefaults.standard.string(forKey: selectedCharityKey) ?? ""
    }

    /// Set selected charity in both UserDefaults and Firestore (matches Android).
    func setSelectedCharity(_ charityId: String) async throws {
        UserDefaults.standard.set(charityId, forKey: selectedCharityKey)

        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("users").document(uid)
            .collection("charityProfile").document("profile")
            .setData(["selectedCharityId": charityId], merge: true)
    }

    // MARK: - Record Charity Points

    /// Record charity points after a walk is completed.
    /// Points formula: `Int(distanceMeters / 10)` (matching Android: 2300m = 230 points).
    ///
    /// Updates 3 Firestore locations (matching Android exactly):
    /// 1. `users/{uid}/charityProfile/profile` - increment lifetimePoints, monthlyPoints, set lastWalkCharityPoints
    /// 2. `charity_monthly/{YYYY-MM}` - increment totalPoints and charityPoints.{charityId}
    /// 3. `charity_monthly/{YYYY-MM}/user_contributions/{uid}` - increment points, walkCount
    ///
    /// - Parameter distanceMeters: The walk distance in meters.
    /// - Returns: The number of charity points earned (0 if not eligible).
    func recordCharityPoints(distanceMeters: Double) async -> Int64 {
        guard isCharityEnabled() else {
            print("[CharityRepository] Charity not enabled, no points awarded")
            return 0
        }

        guard let uid = auth.currentUser?.uid else {
            print("[CharityRepository] No authenticated user, cannot record charity points")
            return 0
        }

        let charityId = getSelectedCharityId()
        guard !charityId.isEmpty else {
            print("[CharityRepository] No charity selected, no points awarded")
            return 0
        }

        // Verify the selected charity exists
        guard CharityOrg.supportedCharities.contains(where: { $0.id == charityId }) else {
            print("[CharityRepository] Invalid charity ID: \(charityId)")
            return 0
        }

        // km * 100 points, so 2300m = 2.3km = 230 points (matches Android: distanceMeters / 10)
        let points = Int64(distanceMeters / 10.0)
        guard points > 0 else {
            print("[CharityRepository] Walk too short for charity points")
            return 0
        }

        do {
            // 1. Update user's charity profile
            let profileRef = db.collection("users").document(uid)
                .collection("charityProfile").document("profile")

            try await profileRef.setData([
                "lifetimePoints": FieldValue.increment(points),
                "monthlyPoints": FieldValue.increment(points),
                "lastWalkCharityPoints": points,
                "selectedCharityId": charityId,
                "enabled": true
            ], merge: true)

            // 2. Update monthly aggregate
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"
            let yearMonth = dateFormatter.string(from: Date())
            let monthlyRef = db.collection("charity_monthly").document(yearMonth)

            try await monthlyRef.setData([
                "totalPoints": FieldValue.increment(points),
                "charityPoints.\(charityId)": FieldValue.increment(points)
            ], merge: true)

            // 3. Update user contribution for this month
            try await monthlyRef.collection("user_contributions").document(uid)
                .setData([
                    "points": FieldValue.increment(points),
                    "charityId": charityId,
                    "walkCount": FieldValue.increment(Int64(1))
                ], merge: true)

            print("[CharityRepository] Charity points recorded: \(points) points for \(charityId)")
            return points
        } catch {
            print("[CharityRepository] Failed to record charity points: \(error)")
            return 0
        }
    }

    // MARK: - Monthly Leaderboard

    /// Get the monthly leaderboard: query `charity_monthly/{currentMonth}/user_contributions` ordered by points descending.
    func getMonthlyLeaderboard() async throws -> [CharityLeaderboardEntry] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        let yearMonth = dateFormatter.string(from: Date())

        let snapshot = try await db.collection("charity_monthly").document(yearMonth)
            .collection("user_contributions")
            .order(by: "points", descending: true)
            .limit(to: 50)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let points = data["points"] as? Int64 else { return nil }
            return CharityLeaderboardEntry(
                id: doc.documentID,
                points: points,
                charityId: data["charityId"] as? String ?? "",
                walkCount: data["walkCount"] as? Int64 ?? 0
            )
        }
    }

    // MARK: - Helpers

    /// Get the charity name for a given ID.
    func getCharityName(_ charityId: String) -> String {
        return CharityOrg.supportedCharities.first { $0.id == charityId }?.name ?? ""
    }

    /// Get the charity emoji for a given ID.
    func getCharityEmoji(_ charityId: String) -> String {
        return CharityOrg.supportedCharities.first { $0.id == charityId }?.logoEmoji ?? ""
    }

    /// Sync local UserDefaults from Firestore profile (call on app launch / login).
    func syncFromFirestore() async {
        guard let profile = try? await getCharityProfile() else { return }
        UserDefaults.standard.set(profile.enabled, forKey: charityEnabledKey)
        UserDefaults.standard.set(profile.selectedCharityId, forKey: selectedCharityKey)
    }
}
