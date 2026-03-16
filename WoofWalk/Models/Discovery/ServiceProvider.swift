import Foundation
import FirebaseFirestore

struct ServiceProviderLite: Identifiable, Codable {
    var id: String
    var name: String
    var photoUrl: String?
    var rating: Double?
    var reviewCount: Int?
    var priceRange: String?
    var services: [String]
    var distance: Double?
    var hasBackgroundCheck: Bool
    var hasInsurance: Bool
    var acceptingNewClients: Bool
    var isExternal: Bool

    init(id: String = UUID().uuidString, name: String = "", photoUrl: String? = nil, rating: Double? = nil, reviewCount: Int? = nil, priceRange: String? = nil, services: [String] = [], distance: Double? = nil, hasBackgroundCheck: Bool = false, hasInsurance: Bool = false, acceptingNewClients: Bool = true, isExternal: Bool = false) {
        self.id = id; self.name = name; self.photoUrl = photoUrl; self.rating = rating; self.reviewCount = reviewCount; self.priceRange = priceRange; self.services = services; self.distance = distance; self.hasBackgroundCheck = hasBackgroundCheck; self.hasInsurance = hasInsurance; self.acceptingNewClients = acceptingNewClients; self.isExternal = isExternal
    }
}

enum DiscoveryServiceType: String, CaseIterable {
    case all = "All"
    case walk = "Walking"
    case grooming = "Grooming"
    case sitting = "Sitting"
    case boarding = "Boarding"
    case daycare = "Daycare"
    case training = "Training"
    case vet = "Vet"
}
