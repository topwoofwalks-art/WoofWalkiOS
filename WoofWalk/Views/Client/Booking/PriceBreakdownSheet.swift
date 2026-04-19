import SwiftUI

/// A sheet presenting the full price breakdown for a booking, including
/// applied discounts (removable) and available discounts (applicable).
struct PriceBreakdownSheet: View {
    let basePrice: Double
    let additionalDogFee: Double
    let durationAdjustment: Double
    let platformFee: Double
    let discountLineItems: [DiscountLineItem]
    let availableDiscounts: [BusinessDiscount]
    let appliedDiscountIds: Set<String>
    let total: Double
    let onApply: (String) -> Void
    let onRemove: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed

    private var subtotal: Double {
        basePrice + additionalDogFee + durationAdjustment
    }

    private var totalDiscount: Double {
        discountLineItems.reduce(0) { $0 + $1.amount }
    }

    private var unappliedDiscounts: [BusinessDiscount] {
        availableDiscounts.filter { discount in
            guard let id = discount.id else { return false }
            return !appliedDiscountIds.contains(id)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                serviceSection
                discountSection
                feesSection
                totalSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Price Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var serviceSection: some View {
        Section("Service") {
            priceRow("Base price", amount: basePrice)

            if additionalDogFee > 0 {
                priceRow("Additional dogs", amount: additionalDogFee)
            }

            if durationAdjustment > 0 {
                priceRow("Duration adjustment", amount: durationAdjustment)
            }

            HStack {
                Text("Subtotal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(CurrencyFormatter.shared.formatPrice(subtotal))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }

    private var discountSection: some View {
        Section("Discounts") {
            // Applied discounts
            if discountLineItems.isEmpty && unappliedDiscounts.isEmpty {
                Text("No discounts available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(discountLineItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.type.icon)
                        .foregroundStyle(.green)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.discountName)
                            .font(.subheadline)
                            .foregroundStyle(.green)
                        if !item.description.isEmpty {
                            Text(item.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(CurrencyFormatter.shared.formatDiscount(abs(item.amount)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)

                    Button {
                        onRemove(item.discountId)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Available (unapplied) discounts
            ForEach(unappliedDiscounts) { discount in
                if let discountId = discount.id {
                    HStack(spacing: 12) {
                        Image(systemName: discount.type.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(discount.name)
                                .font(.subheadline)
                            if !discount.description.isEmpty {
                                Text(discount.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            discountValueLabel(discount)
                        }

                        Spacer()

                        Button {
                            onApply(discountId)
                        } label: {
                            Text("Apply")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var feesSection: some View {
        Section("Fees") {
            priceRow("Platform fee (10%)", amount: platformFee)
        }
    }

    private var totalSection: some View {
        Section {
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(CurrencyFormatter.shared.formatPrice(total))
                    .font(.title2)
                    .bold()
            }
        }
    }

    // MARK: - Helpers

    private func priceRow(_ label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(CurrencyFormatter.shared.formatPrice(amount))
                .font(.subheadline)
        }
    }

    private func discountValueLabel(_ discount: BusinessDiscount) -> some View {
        Group {
            if discount.percentOff > 0 {
                Text("\(Int(discount.percentOff))% off")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if discount.amountOff > 0 {
                Text("\(CurrencyFormatter.shared.formatPrice(discount.amountOff)) off")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PriceBreakdownSheet_Previews: PreviewProvider {
    static var previews: some View {
        PriceBreakdownSheet(
            basePrice: 25.0,
            additionalDogFee: 10.0,
            durationAdjustment: 5.0,
            platformFee: 4.0,
            discountLineItems: [
                DiscountLineItem(
                    discountId: "d1",
                    discountName: "Multi-Dog Discount",
                    type: .MULTI_DOG,
                    amount: -5.0,
                    description: "10% off for 2+ dogs"
                )
            ],
            availableDiscounts: [
                BusinessDiscount(
                    type: .FIRST_BOOKING,
                    name: "First Booking",
                    description: "20% off your first walk",
                    percentOff: 20
                )
            ],
            appliedDiscountIds: ["d1"],
            total: 34.0,
            onApply: { _ in },
            onRemove: { _ in }
        )
    }
}
#endif
