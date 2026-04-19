import Foundation

// MARK: - Walk Service Configuration

/// A walk duration/price variant (e.g. "30 min - 12.00", "60 min - 18.00").
struct WalkDurationOption: Identifiable, Codable, Equatable {
    var id: String
    var durationMinutes: Int
    var price: Double
    var label: String?
    var isActive: Bool

    /// Display label, falling back to generated text
    var displayLabel: String {
        if let label = label, !label.isEmpty { return label }
        return "\(durationMinutes) min"
    }

    init(
        id: String = UUID().uuidString,
        durationMinutes: Int = 60,
        price: Double = 0.0,
        label: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.durationMinutes = durationMinutes
        self.price = price
        self.label = label
        self.isActive = isActive
    }
}

/// Group walk settings for a business.
struct GroupWalkSettings: Codable, Equatable {
    var isOffered: Bool
    var maxDogsPerWalk: Int
    var additionalDogDiscount: Double
    var groupPricePerDog: Double?

    init(
        isOffered: Bool = true,
        maxDogsPerWalk: Int = 4,
        additionalDogDiscount: Double = 0.0,
        groupPricePerDog: Double? = nil
    ) {
        self.isOffered = isOffered
        self.maxDogsPerWalk = maxDogsPerWalk
        self.additionalDogDiscount = additionalDogDiscount
        self.groupPricePerDog = groupPricePerDog
    }
}

/// Full walk service configuration for a business.
struct WalkServiceConfig: Codable, Equatable {
    var variants: [WalkDurationOption]
    var groupWalk: GroupWalkSettings

    init(
        variants: [WalkDurationOption] = [],
        groupWalk: GroupWalkSettings = GroupWalkSettings()
    ) {
        self.variants = variants
        self.groupWalk = groupWalk
    }
}
