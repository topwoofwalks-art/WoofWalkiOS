import Foundation

// MARK: - Grooming Service Configuration

/// Dog size categories for grooming pricing tiers.
enum DogSize: String, Codable, CaseIterable {
    case small = "SMALL"
    case medium = "MEDIUM"
    case large = "LARGE"
    case giant = "GIANT"

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .giant: return "Giant"
        }
    }

    static func from(string: String?) -> DogSize {
        guard let string = string else { return .medium }
        return DogSize(rawValue: string) ?? .medium
    }
}

/// A single grooming menu item (e.g. "Full Groom", "Bath & Dry").
struct GroomingMenuItem: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var basePrice: Double
    var durationMinutes: Int
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        basePrice: Double = 0.0,
        durationMinutes: Int = 60,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.basePrice = basePrice
        self.durationMinutes = durationMinutes
        self.isActive = isActive
    }
}

/// A grooming package bundling multiple services at a discount.
struct GroomingPackage: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var includedItemIds: [String]
    var price: Double
    var durationMinutes: Int
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        includedItemIds: [String] = [],
        price: Double = 0.0,
        durationMinutes: Int = 90,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.includedItemIds = includedItemIds
        self.price = price
        self.durationMinutes = durationMinutes
        self.isActive = isActive
    }
}

/// Size-based price adjustment for grooming services.
struct GroomingSizePricing: Codable, Equatable {
    var size: String
    var multiplier: Double
    var flatSurcharge: Double

    var dogSize: DogSize {
        DogSize.from(string: size)
    }

    init(
        size: String = DogSize.medium.rawValue,
        multiplier: Double = 1.0,
        flatSurcharge: Double = 0.0
    ) {
        self.size = size
        self.multiplier = multiplier
        self.flatSurcharge = flatSurcharge
    }
}

/// An optional grooming add-on (e.g. "Nail Painting", "Teeth Cleaning").
struct GroomingAddOn: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var price: Double
    var durationMinutes: Int
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        price: Double = 0.0,
        durationMinutes: Int = 15,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.durationMinutes = durationMinutes
        self.isActive = isActive
    }
}

/// Full grooming service configuration for a business.
struct GroomingServiceConfig: Codable, Equatable {
    var menuItems: [GroomingMenuItem]
    var packages: [GroomingPackage]
    var sizePricing: [GroomingSizePricing]
    var addOns: [GroomingAddOn]

    init(
        menuItems: [GroomingMenuItem] = [],
        packages: [GroomingPackage] = [],
        sizePricing: [GroomingSizePricing] = [],
        addOns: [GroomingAddOn] = []
    ) {
        self.menuItems = menuItems
        self.packages = packages
        self.sizePricing = sizePricing
        self.addOns = addOns
    }
}
