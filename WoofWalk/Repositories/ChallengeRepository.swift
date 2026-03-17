import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class ChallengeRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    func getActiveChallenges() -> AnyPublisher<[Challenge], Error> {
        let publisher = PassthroughSubject<[Challenge], Error>()
        db.collection("challenges")
            .whereField("isActive", isEqualTo: true)
            .order(by: "startDate", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error { publisher.send(completion: .failure(error)); return }
                let challenges = (snapshot?.documents ?? []).compactMap { try? $0.data(as: Challenge.self) }
                publisher.send(challenges)
            }
        return publisher.eraseToAnyPublisher()
    }

    func getChallenge(byId challengeId: String) async throws -> Challenge? {
        let doc = try await db.collection("challenges").document(challengeId).getDocument()
        return try? doc.data(as: Challenge.self)
    }

    func joinChallenge(_ challengeId: String) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        let userDoc = try await db.collection("users").document(uid).getDocument()
        let userName = userDoc.data()?["username"] as? String ?? "User"
        let userAvatar = userDoc.data()?["photoUrl"] as? String

        let participant = ChallengeParticipant(userId: uid, userName: userName, userAvatar: userAvatar, progress: 0, rank: 0, joinedAt: Timestamp())
        try db.collection("challenges").document(challengeId).collection("participants").document(uid).setData(from: participant)
        try await db.collection("challenges").document(challengeId).updateData([
            "participantIds": FieldValue.arrayUnion([uid]),
            "participantCount": FieldValue.increment(Int64(1))
        ])
    }

    func updateProgress(challengeId: String, progress: Double) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("challenges").document(challengeId).collection("participants").document(uid).updateData(["progress": progress])
    }

    func getLeaderboard(challengeId: String) async throws -> [ChallengeParticipant] {
        let snapshot = try await db.collection("challenges").document(challengeId).collection("participants")
            .order(by: "progress", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ChallengeParticipant.self) }
    }
}
