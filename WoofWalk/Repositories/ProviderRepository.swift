import Foundation
import FirebaseFirestore
import CoreLocation

class ProviderRepository {
    private let db = Firestore.firestore()

    /// Search providers within a radius of a given location, filtered by service type.
    /// Uses client-side Haversine distance filtering since Firestore does not support geo queries natively.
    func searchProviders(
        serviceType: String,
        location: CLLocationCoordinate2D,
        radiusKm: Double = 25
    ) async throws -> [ServiceProviderLite] {
        // Map ServiceType display name to Firestore service field value
        let firestoreServiceName = mapServiceTypeToFirestoreValue(serviceType)

        var query: Query = db.collection("businesses")
        if !firestoreServiceName.isEmpty {
            query = query.whereField("services", arrayContains: firestoreServiceName)
        }

        let snapshot = try await query.limit(to: 100).getDocuments()

        let providers: [ServiceProviderLite] = snapshot.documents.compactMap { doc in
            var provider = try? doc.data(as: ServiceProviderLite.self)
            provider?.id = doc.documentID
            return provider
        }
        .filter { $0.acceptingNewClients }
        .compactMap { provider -> ServiceProviderLite? in
            guard let lat = provider.latitude, let lng = provider.longitude else {
                // Providers without coordinates are excluded from location-based search
                return nil
            }
            let distanceKm = haversineDistance(
                lat1: location.latitude, lon1: location.longitude,
                lat2: lat, lon2: lng
            )
            guard distanceKm <= radiusKm else { return nil }
            var result = provider
            result.distance = distanceKm
            return result
        }
        .sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }

        return Array(providers.prefix(30))
    }

    /// Fetch full provider detail by ID.
    func getProviderDetail(providerId: String) async throws -> ServiceProviderLite? {
        let doc = try await db.collection("businesses").document(providerId).getDocument()
        var provider = try? doc.data(as: ServiceProviderLite.self)
        provider?.id = doc.documentID
        return provider
    }

    /// Fetch reviews for a provider.
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

    // MARK: - Helpers

    /// Map the ServiceType display name to the value stored in Firestore's services array.
    private func mapServiceTypeToFirestoreValue(_ serviceType: String) -> String {
        switch serviceType {
        case "Daily Walks": return "Walking"
        case "In-Home Sitting": return "Sitting"
        case "Daycare": return "Daycare"
        case "Overnight Boarding": return "Boarding"
        case "Grooming": return "Grooming"
        case "Training": return "Training"
        default: return serviceType
        }
    }

    /// Haversine formula to calculate distance between two coordinates in kilometres.
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadiusKm = 6371.0

        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0

        let lat1Rad = lat1 * .pi / 180.0
        let lat2Rad = lat2 * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusKm * c
    }
}
