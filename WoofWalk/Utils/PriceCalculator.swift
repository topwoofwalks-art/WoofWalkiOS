import Foundation

/// Calculates booking prices matching Android's BookingFlowViewModel.calculateCurrentPrice logic.
enum PriceCalculator {

    // MARK: - Constants

    /// Default base price when provider has no custom pricing
    static let defaultBasePrice: Double = 25.0

    /// Default additional dog fee per extra dog
    static let defaultAdditionalDogFee: Double = 5.0

    /// Duration threshold in minutes before adjustment kicks in
    static let durationThresholdMinutes: Double = 60.0

    /// Cost per 30-minute block over the threshold
    static let durationBlockCost: Double = 5.0

    /// Duration block size in minutes
    static let durationBlockMinutes: Double = 30.0

    /// Platform fee percentage (10%)
    static let platformFeeRate: Double = 0.10

    // MARK: - Calculation

    /// Calculate a full price breakdown for a booking.
    ///
    /// Logic matches Android exactly:
    /// - Base: provider's base price for the service (or default £25)
    /// - Additional dogs: fee per dog beyond the first (default £5 each)
    /// - Duration adjustment: +£5 per 30min block over 60 minutes
    /// - Platform fee: 10% of subtotal
    /// - Discount: from applied promo code
    ///
    /// - Parameters:
    ///   - serviceType: The type of service being booked
    ///   - dogCount: Number of dogs included in the booking
    ///   - durationMinutes: Duration of the service in minutes
    ///   - providerBasePrice: Provider's custom base price, or nil for default
    ///   - providerAdditionalDogFee: Provider's custom per-extra-dog fee, or nil for default
    ///   - promoDiscount: Applied promo code discount, if any
    /// - Returns: A fully calculated PriceBreakdown
    static func calculatePrice(
        serviceType: BookingServiceType,
        dogCount: Int,
        durationMinutes: Int,
        providerBasePrice: Double? = nil,
        providerAdditionalDogFee: Double? = nil,
        promoDiscount: PromoCodeDiscount? = nil
    ) -> PriceBreakdown {
        let basePrice = providerBasePrice ?? defaultBasePrice
        let additionalDogFeeRate = providerAdditionalDogFee ?? defaultAdditionalDogFee

        // Extra dogs cost
        let extraDogsCost = dogCount > 1
            ? additionalDogFeeRate * Double(dogCount - 1)
            : 0.0

        // Duration adjustment: +£5 per 30min block over 60 minutes
        let durationAdjustment: Double
        if Double(durationMinutes) > durationThresholdMinutes {
            durationAdjustment = (Double(durationMinutes) - durationThresholdMinutes) / durationBlockMinutes * durationBlockCost
        } else {
            durationAdjustment = 0.0
        }

        let subtotal = basePrice + extraDogsCost + durationAdjustment
        let platformFee = subtotal * platformFeeRate
        let discount = promoDiscount?.calculatedDiscount ?? 0.0

        return PriceBreakdown(
            basePrice: basePrice,
            additionalDogFee: extraDogsCost,
            durationAdjustment: durationAdjustment,
            platformFee: platformFee,
            discount: discount,
            taxes: 0.0
        )
    }

    // MARK: - Promo Codes

    /// Apply a promo code and return the discount.
    /// Currently supports placeholder codes for testing.
    static func applyPromoCode(_ code: String, subtotal: Double) -> PromoCodeDiscount? {
        let normalised = code.uppercased().trimmingCharacters(in: .whitespaces)

        // Placeholder promo codes matching Android's hardcoded logic
        switch normalised {
        case "WELCOME10":
            let discountAmount = subtotal * 0.10
            return PromoCodeDiscount(
                code: normalised,
                description: "10% off your first booking",
                percentOff: 10.0,
                amountOff: nil,
                calculatedDiscount: discountAmount
            )
        default:
            return nil
        }
    }

    // MARK: - Formatting

    /// Format a price amount with currency symbol and 2 decimal places.
    static func formatPrice(_ amount: Double) -> String {
        CurrencyFormatter.shared.formatPrice(amount)
    }

    /// Format a price amount with sign (for discounts shown as negative).
    static func formatDiscount(_ amount: Double) -> String {
        CurrencyFormatter.shared.formatDiscount(amount)
    }
}
