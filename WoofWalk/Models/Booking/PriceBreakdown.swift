import Foundation

/// Itemized price breakdown for a booking, matching Android's PriceBreakdown model.
struct PriceBreakdown: Codable, Equatable {
    var basePrice: Double = 0.0
    var additionalDogFee: Double = 0.0
    var durationAdjustment: Double = 0.0
    var platformFee: Double = 0.0
    var discount: Double = 0.0
    var taxes: Double = 0.0

    /// Subtotal before platform fee and discounts
    var subtotal: Double {
        basePrice + additionalDogFee + durationAdjustment
    }

    /// Final total after all fees and discounts
    var total: Double {
        subtotal + platformFee - discount + taxes
    }
}

/// Promo code discount information, matching Android's PromoCodeDiscount.
struct PromoCodeDiscount: Codable, Equatable {
    var code: String
    var description: String
    var percentOff: Double?
    var amountOff: Double?
    var calculatedDiscount: Double = 0.0
}
