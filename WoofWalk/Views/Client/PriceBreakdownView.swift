import SwiftUI

/// Displays an itemized price breakdown for a booking.
/// Matches Android's price breakdown UI with base price, extra dogs,
/// duration adjustment, platform fee, discount, and total.
struct PriceBreakdownView: View {
    let breakdown: PriceBreakdown

    var body: some View {
        VStack(spacing: 8) {
            // Base Price
            priceRow(label: "Base Price", amount: breakdown.basePrice)

            // Additional Dogs (only show if non-zero)
            if breakdown.additionalDogFee > 0 {
                priceRow(
                    label: "Additional Dogs",
                    amount: breakdown.additionalDogFee
                )
            }

            // Duration Adjustment (only show if non-zero)
            if breakdown.durationAdjustment > 0 {
                priceRow(
                    label: "Duration Adjustment",
                    amount: breakdown.durationAdjustment
                )
            }

            // Platform Fee
            priceRow(
                label: "Platform Fee (10%)",
                amount: breakdown.platformFee
            )

            // Discount (only show if non-zero)
            if breakdown.discount > 0 {
                HStack {
                    Text("Discount")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                    Text(PriceCalculator.formatDiscount(breakdown.discount))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }

            // Taxes (only show if non-zero)
            if breakdown.taxes > 0 {
                priceRow(label: "Taxes", amount: breakdown.taxes)
            }

            Divider()

            // Total
            HStack {
                Text("Total")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(PriceCalculator.formatPrice(breakdown.total))
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func priceRow(label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(PriceCalculator.formatPrice(amount))
                .font(.subheadline)
        }
    }
}

#if DEBUG
struct PriceBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        PriceBreakdownView(
            breakdown: PriceBreakdown(
                basePrice: 25.0,
                additionalDogFee: 10.0,
                durationAdjustment: 5.0,
                platformFee: 4.0,
                discount: 4.0,
                taxes: 0.0
            )
        )
        .previewLayout(.sizeThatFits)
    }
}
#endif
