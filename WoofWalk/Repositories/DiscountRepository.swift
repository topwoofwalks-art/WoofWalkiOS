import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class DiscountRepository: ObservableObject {
    private let db = Firestore.firestore()

    @Published var discounts: [BusinessDiscount] = []
    private var listener: ListenerRegistration?

    func observeDiscounts(orgId: String) {
        listener?.remove()
        listener = db.collection("organization_settings")
            .document(orgId)
            .collection("discounts")
            .order(by: "priority")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error observing discounts: \(error)")
                    return
                }
                self?.discounts = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: BusinessDiscount.self)
                } ?? []
            }
    }

    func getActiveDiscounts(orgId: String, serviceType: String) async -> [BusinessDiscount] {
        do {
            let snapshot = try await db.collection("organization_settings")
                .document(orgId)
                .collection("discounts")
                .whereField("isActive", isEqualTo: true)
                .order(by: "priority")
                .getDocuments()
            return snapshot.documents.compactMap { doc in
                guard let discount = try? doc.data(as: BusinessDiscount.self) else { return nil }
                return discount.appliesTo(serviceType) && discount.isCurrentlyValid ? discount : nil
            }
        } catch {
            print("Failed to fetch discounts: \(error)")
            return []
        }
    }

    func createDiscount(orgId: String, discount: BusinessDiscount) async throws -> String {
        var d = discount
        d.createdAt = Timestamp()
        d.updatedAt = Timestamp()
        let ref = try db.collection("organization_settings")
            .document(orgId)
            .collection("discounts")
            .addDocument(from: d)
        return ref.documentID
    }

    func updateDiscount(orgId: String, discount: BusinessDiscount) async throws {
        guard let id = discount.id else { return }
        var d = discount
        d.updatedAt = Timestamp()
        try db.collection("organization_settings")
            .document(orgId)
            .collection("discounts")
            .document(id)
            .setData(from: d, merge: true)
    }

    func deleteDiscount(orgId: String, discountId: String) async throws {
        try await db.collection("organization_settings")
            .document(orgId)
            .collection("discounts")
            .document(discountId)
            .delete()
    }

    func toggleDiscount(orgId: String, discountId: String, isActive: Bool) async throws {
        try await db.collection("organization_settings")
            .document(orgId)
            .collection("discounts")
            .document(discountId)
            .updateData(["isActive": isActive, "updatedAt": Timestamp()])
    }

    deinit { listener?.remove() }
}
