import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Reads + writes dog medical records in the
/// `/dogs/{dogId}/medicalRecords/{recordId}` subcollection.
///
/// Access is enforced by Firestore rules (see `firestore.rules` around
/// line 2398): only the primary owner, a co-owner, or an org-member
/// whose org has `canViewMedical == true` can read; only the primary
/// owner (or platform admin) can write.
final class MedicalRecordsRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    private func subcollection(dogId: String) -> CollectionReference {
        db.collection("dogs").document(dogId).collection("medicalRecords")
    }

    /// Real-time stream of all medical records for a dog, newest-first.
    func observeRecords(dogId: String) -> AnyPublisher<[MedicalRecord], Error> {
        let subject = PassthroughSubject<[MedicalRecord], Error>()
        let listener = subcollection(dogId: dogId)
            .order(by: "recordedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                let records = snapshot?.documents.compactMap { doc -> MedicalRecord? in
                    try? doc.data(as: MedicalRecord.self)
                } ?? []
                subject.send(records)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Records of a specific type (e.g. `.vaccination`).
    func observeRecords(dogId: String, type: MedicalRecordType) -> AnyPublisher<[MedicalRecord], Error> {
        let subject = PassthroughSubject<[MedicalRecord], Error>()
        let listener = subcollection(dogId: dogId)
            .whereField("type", isEqualTo: type.rawValue)
            .order(by: "recordedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }
                let records = snapshot?.documents.compactMap { doc -> MedicalRecord? in
                    try? doc.data(as: MedicalRecord.self)
                } ?? []
                subject.send(records)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    @discardableResult
    func addRecord(dogId: String, record: MedicalRecord) async throws -> String {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(
                domain: "MedicalRecordsRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var payload = record
        payload.dogId = dogId
        if payload.recordedBy.isEmpty {
            payload.recordedBy = uid
        }
        if payload.recordedAt == 0 {
            payload.recordedAt = now
        }
        payload.updatedAt = now
        let ref = try subcollection(dogId: dogId).addDocument(from: payload)
        return ref.documentID
    }

    func updateRecord(dogId: String, recordId: String, record: MedicalRecord) async throws {
        var payload = record
        payload.dogId = dogId
        payload.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        try subcollection(dogId: dogId).document(recordId).setData(from: payload, merge: true)
    }

    func deleteRecord(dogId: String, recordId: String) async throws {
        try await subcollection(dogId: dogId).document(recordId).delete()
    }
}
