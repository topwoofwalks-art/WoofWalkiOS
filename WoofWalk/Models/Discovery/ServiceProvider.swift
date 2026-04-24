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

    // Detail fields
    var bio: String?
    var experience: String?
    var responseTime: String?
    var phone: String?
    var email: String?
    var website: String?
    var heroPhotoUrl: String?
    var latitude: Double?
    var longitude: Double?
    var isPartner: Bool
    var availableNow: Bool
    var servicePricing: [ServicePriceItem]
    /// Date the business was most recently verified. Feeds the tenure
    /// bonus in BusinessRanker — nil for unclaimed / unverified providers.
    var verifiedSince: Date?

    init(id: String = UUID().uuidString, name: String = "", photoUrl: String? = nil, rating: Double? = nil, reviewCount: Int? = nil, priceRange: String? = nil, services: [String] = [], distance: Double? = nil, hasBackgroundCheck: Bool = false, hasInsurance: Bool = false, acceptingNewClients: Bool = true, isExternal: Bool = false, bio: String? = nil, experience: String? = nil, responseTime: String? = nil, phone: String? = nil, email: String? = nil, website: String? = nil, heroPhotoUrl: String? = nil, latitude: Double? = nil, longitude: Double? = nil, isPartner: Bool = false, availableNow: Bool = false, servicePricing: [ServicePriceItem] = [], verifiedSince: Date? = nil) {
        self.id = id; self.name = name; self.photoUrl = photoUrl; self.rating = rating; self.reviewCount = reviewCount; self.priceRange = priceRange; self.services = services; self.distance = distance; self.hasBackgroundCheck = hasBackgroundCheck; self.hasInsurance = hasInsurance; self.acceptingNewClients = acceptingNewClients; self.isExternal = isExternal; self.bio = bio; self.experience = experience; self.responseTime = responseTime; self.phone = phone; self.email = email; self.website = website; self.heroPhotoUrl = heroPhotoUrl; self.latitude = latitude; self.longitude = longitude; self.isPartner = isPartner; self.availableNow = availableNow; self.servicePricing = servicePricing; self.verifiedSince = verifiedSince
    }
}

struct ServicePriceItem: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var price: Double
    var currencyCode: String
    var duration: String?

    init(name: String, price: Double, currencyCode: String = "GBP", duration: String? = nil) {
        self.name = name
        self.price = price
        self.currencyCode = currencyCode
        self.duration = duration
    }
}

struct ProviderReview: Identifiable, Codable {
    var id: String
    var authorName: String
    var authorPhotoUrl: String?
    var rating: Double
    var text: String
    var date: Date

    init(id: String = UUID().uuidString, authorName: String = "", authorPhotoUrl: String? = nil, rating: Double = 5, text: String = "", date: Date = Date()) {
        self.id = id; self.authorName = authorName; self.authorPhotoUrl = authorPhotoUrl; self.rating = rating; self.text = text; self.date = date
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

enum DiscoverySortOption: String, CaseIterable {
    case distance = "Distance"
    case topRated = "Top Rated"
    case priceLow = "Price Low→High"
    case priceHigh = "Price High→Low"
    case mostReviews = "Most Reviews"
}
