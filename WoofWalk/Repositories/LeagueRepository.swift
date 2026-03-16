import Foundation
import FirebaseAuth
import FirebaseFirestore

class LeagueRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    func getCurrentLeagueState() async throws -> WeeklyLeagueState? {
        guard let uid = auth.currentUser?.uid else { return nil }
        let userDoc = try await db.collection("users").document(uid).getDocument()
        guard let data = userDoc.data(),
              let groupId = data["leagueGroupId"] as? String,
              let weekId = data["leagueWeekId"] as? String,
              let tierStr = data["leagueTier"] as? String else { return nil }

        let tier = LeagueTier(rawValue: tierStr) ?? .bronze
        let groupDoc = try await db.collection("leagues").document(weekId).collection("groups").document(groupId).getDocument()
        let participantIds = groupDoc.data()?["participantIds"] as? [String] ?? []

        let participantSet = Set(participantIds)
        let snapshot = try await db.collection("leagues").document(weekId).collection("scores").getDocuments()
        var participants: [RankedParticipant] = []
        for doc in snapshot.documents {
            let data = doc.data()
            let userId = data["userId"] as? String ?? doc.documentID
            guard participantSet.contains(userId) else { continue }
            participants.append(RankedParticipant(
                userId: userId,
                displayName: data["displayName"] as? String ?? "",
                photoUrl: data["photoUrl"] as? String,
                weeklyPoints: data["weeklyPoints"] as? Int64 ?? 0,
                rank: 0
            ))
        }

        participants.sort { $0.weeklyPoints > $1.weeklyPoints }
        for i in participants.indices { participants[i].rank = i + 1 }

        return WeeklyLeagueState(weekId: weekId, tier: tier, groupId: groupId, participants: participants, currentUserId: uid)
    }

    func addWeeklyPoints(_ points: Int64) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        let userDoc = try await db.collection("users").document(uid).getDocument()
        guard let weekId = userDoc.data()?["leagueWeekId"] as? String else { return }
        try await db.collection("leagues").document(weekId).collection("scores").document(uid).updateData([
            "weeklyPoints": FieldValue.increment(points)
        ])
    }
}
