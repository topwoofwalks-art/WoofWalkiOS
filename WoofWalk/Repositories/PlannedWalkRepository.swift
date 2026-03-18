import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class PlannedWalkRepository: ObservableObject {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    private var currentUserId: String? {
        auth.currentUser?.uid
    }

    private func plannedWalksCollection() -> CollectionReference? {
        guard let uid = currentUserId else { return nil }
        return db.collection("users").document(uid).collection("plannedWalks")
    }

    // MARK: - Save

    func savePlannedWalk(_ walk: PlannedWalk) async throws -> String {
        guard let collection = plannedWalksCollection() else {
            throw NSError(domain: "PlannedWalkRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        var walkToSave = walk
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        if walkToSave.id == nil || walkToSave.id!.isEmpty {
            walkToSave.id = UUID().uuidString
        }
        if walkToSave.userId.isEmpty {
            walkToSave.userId = currentUserId ?? ""
        }
        if walkToSave.createdAt == 0 {
            walkToSave.createdAt = now
        }
        walkToSave.updatedAt = now

        let docId = walkToSave.id!
        try collection.document(docId).setData(from: walkToSave)
        print("Saved planned walk: \(docId)")
        return docId
    }

    // MARK: - Get All (Publisher)

    func getPlannedWalks() -> AnyPublisher<[PlannedWalk], Error> {
        guard let collection = plannedWalksCollection() else {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        let publisher = PassthroughSubject<[PlannedWalk], Error>()

        collection
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("PlannedWalkRepository: Error listening for walks: \(error.localizedDescription)")
                    publisher.send([])
                    return
                }

                guard let snapshot = snapshot else {
                    publisher.send([])
                    return
                }

                let walks = snapshot.documents.compactMap { doc -> PlannedWalk? in
                    try? doc.data(as: PlannedWalk.self)
                }
                publisher.send(walks)
            }

        return publisher.eraseToAnyPublisher()
    }

    // MARK: - Get Single

    func getPlannedWalk(id: String) async throws -> PlannedWalk? {
        guard let collection = plannedWalksCollection() else {
            throw NSError(domain: "PlannedWalkRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let doc = try await collection.document(id).getDocument()
        guard doc.exists else { return nil }
        return try doc.data(as: PlannedWalk.self)
    }

    // MARK: - Delete

    func deletePlannedWalk(id: String) async throws {
        guard let collection = plannedWalksCollection() else {
            throw NSError(domain: "PlannedWalkRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try await collection.document(id).delete()
        print("Deleted planned walk: \(id)")
    }

    // MARK: - Mark as Completed

    func markAsCompleted(plannedWalkId: String, completedWalkId: String) async throws {
        guard let collection = plannedWalksCollection() else {
            throw NSError(domain: "PlannedWalkRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try await collection.document(plannedWalkId).updateData([
            "completedWalkId": completedWalkId,
            "updatedAt": now
        ])
        print("Marked planned walk as completed: \(plannedWalkId) -> \(completedWalkId)")
    }
}
