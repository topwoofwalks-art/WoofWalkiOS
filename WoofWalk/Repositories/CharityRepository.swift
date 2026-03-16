import Foundation
import FirebaseAuth
import FirebaseFirestore

class CharityRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    func getCharityProfile() async throws -> CharityProfile? {
        guard let uid = auth.currentUser?.uid else { return nil }
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data(), let charityData = data["charityProfile"] as? [String: Any] else { return nil }
        let jsonData = try JSONSerialization.data(withJSONObject: charityData)
        return try JSONDecoder().decode(CharityProfile.self, from: jsonData)
    }

    func updateCharityProfile(_ profile: CharityProfile) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        let encoded = try Firestore.Encoder().encode(profile)
        try await db.collection("users").document(uid).setData(["charityProfile": encoded], merge: true)
    }

    func addCharityPoints(points: Int64) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        let ref = db.collection("users").document(uid)
        var profile = try await getCharityProfile() ?? CharityProfile()
        profile.lifetimePoints += points
        profile.monthlyPoints += points
        profile.lastWalkCharityPoints = points
        let encoded = try Firestore.Encoder().encode(profile)
        try await ref.setData(["charityProfile": encoded], merge: true)
    }
}
