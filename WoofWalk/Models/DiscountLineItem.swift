import Foundation

struct DiscountLineItem: Identifiable {
    let id = UUID()
    let discountId: String
    let discountName: String
    let type: DiscountType
    let amount: Double // negative
    let description: String
}
