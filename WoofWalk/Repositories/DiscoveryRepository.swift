import Foundation
import FirebaseFirestore
import CoreLocation

class DiscoveryRepository {
    private let db = Firestore.firestore()

    func searchProviders(near location: CLLocationCoordinate2D, serviceType: String? = nil, radiusKm: Double = 25) async throws -> [ServiceProviderLite] {
        // Query without composite index: only use single-field filters
        // acceptingNewClients is filtered client-side to avoid needing a composite index
        var query: Query = db.collection("businesses")
        if let type = serviceType, type != "All" {
            query = query.whereField("services", arrayContains: type)
        }
        let snapshot = try await query.limit(to: 100).getDocuments()
        return snapshot.documents.compactMap { doc in
            var provider = try? doc.data(as: ServiceProviderLite.self)
            provider?.id = doc.documentID
            return provider
        }.filter { $0?.acceptingNewClients == true }.compactMap { $0 }
    }

    func getProviderDetails(id: String) async throws -> ServiceProviderLite? {
        let doc = try await db.collection("businesses").document(id).getDocument()
        var provider = try? doc.data(as: ServiceProviderLite.self)
        provider?.id = doc.documentID
        return provider
    }

    func getProviderReviews(providerId: String) async throws -> [ProviderReview] {
        let snapshot = try await db.collection("businesses").document(providerId)
            .collection("reviews")
            .order(by: "date", descending: true)
            .limit(to: 20)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            var review = try? doc.data(as: ProviderReview.self)
            review?.id = doc.documentID
            return review
        }
    }
}
