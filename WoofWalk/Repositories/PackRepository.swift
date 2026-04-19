import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class PackRepository: ObservableObject {
    private let db = Firestore.firestore()

    @Published var packs: [ClientPack] = []
    private var listener: ListenerRegistration?

    func observeMyPacks() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        listener?.remove()
        listener = db.collection("users").document(userId).collection("packs")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error observing packs: \(error)")
                    return
                }
                self?.packs = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: ClientPack.self)
                } ?? []
            }
    }

    func getUsablePacks(orgId: String, serviceType: String) async -> [ClientPack] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        do {
            let snapshot = try await db.collection("users").document(userId).collection("packs")
                .whereField("orgId", isEqualTo: orgId)
                .whereField("serviceType", isEqualTo: serviceType)
                .getDocuments()
            return snapshot.documents.compactMap { doc in
                guard let pack = try? doc.data(as: ClientPack.self) else { return nil }
                return pack.isUsable ? pack : nil
            }
        } catch {
            print("Failed to fetch packs: \(error)")
            return []
        }
    }

    deinit { listener?.remove() }
}
