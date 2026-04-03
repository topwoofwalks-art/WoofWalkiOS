import Foundation
import FirebaseAuth
import FirebaseFirestore

class PoiRepository {
    static let shared = PoiRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    private init() {}

    func createPoi(_ poi: Poi) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(domain: "PoiRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        var poiToSave = poi
        poiToSave.createdBy = userId

        let docRef = db.collection("pois").document()
        poiToSave.id = docRef.documentID
        try docRef.setData(from: poiToSave)
        return docRef.documentID
    }
}
