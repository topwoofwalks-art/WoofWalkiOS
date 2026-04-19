import Foundation

// MARK: - Sitting Service Configuration

/// A sitting visit variant (e.g. "30-min Drop-In", "1-hr Visit").
struct SittingVariant: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var durationMinutes: Int
    var price: Double
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        durationMinutes: Int = 30,
        price: Double = 0.0,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.price = price
        self.isActive = isActive
    }
}

/// Overnight sitting pricing.
struct SittingOvernightPricing: Codable, Equatable {
    var isOffered: Bool
    var pricePerNight: Double
    var additionalDogFee: Double

    init(
        isOffered: Bool = false,
        pricePerNight: Double = 0.0,
        additionalDogFee: Double = 0.0
    ) {
        self.isOffered = isOffered
        self.pricePerNight = pricePerNight
        self.additionalDogFee = additionalDogFee
    }
}

/// Visit-based pricing tiers.
struct SittingVisitPricing: Codable, Equatable {
    var baseVisitPrice: Double
    var additionalDogFee: Double
    var holidaySurchargePercent: Double

    init(
        baseVisitPrice: Double = 0.0,
        additionalDogFee: Double = 0.0,
        holidaySurchargePercent: Double = 0.0
    ) {
        self.baseVisitPrice = baseVisitPrice
        self.additionalDogFee = additionalDogFee
        self.holidaySurchargePercent = holidaySurchargePercent
    }
}

/// Full sitting service configuration for a business.
struct SittingServiceConfig: Codable, Equatable {
    var variants: [SittingVariant]
    var visitPricing: SittingVisitPricing
    var overnight: SittingOvernightPricing

    init(
        variants: [SittingVariant] = [],
        visitPricing: SittingVisitPricing = SittingVisitPricing(),
        overnight: SittingOvernightPricing = SittingOvernightPricing()
    ) {
        self.variants = variants
        self.visitPricing = visitPricing
        self.overnight = overnight
    }
}
