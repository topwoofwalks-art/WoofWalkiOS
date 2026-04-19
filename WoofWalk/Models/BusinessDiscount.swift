import Foundation
import FirebaseFirestore

enum DiscountType: String, Codable, CaseIterable {
    case MULTI_DOG
    case BULK_PACK
    case RECURRING
    case LOYALTY
    case FIRST_BOOKING
    case REFERRAL
    case DURATION
    case CUSTOM

    var displayName: String {
        switch self {
        case .MULTI_DOG: return "Multi-Dog"
        case .BULK_PACK: return "Bulk Pack"
        case .RECURRING: return "Recurring"
        case .LOYALTY: return "Loyalty"
        case .FIRST_BOOKING: return "First Booking"
        case .REFERRAL: return "Referral"
        case .DURATION: return "Duration"
        case .CUSTOM: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .MULTI_DOG: return "pawprint.fill"
        case .BULK_PACK: return "square.stack.3d.up.fill"
        case .RECURRING: return "repeat"
        case .LOYALTY: return "star.fill"
        case .FIRST_BOOKING: return "gift.fill"
        case .REFERRAL: return "person.2.fill"
        case .DURATION: return "clock.fill"
        case .CUSTOM: return "tag.fill"
        }
    }
}

struct BusinessDiscount: Identifiable, Codable {
    @DocumentID var id: String?
    var type: DiscountType = .CUSTOM
    var name: String = ""
    var description: String = ""
    var serviceTypes: [String] = [] // empty = all services
    var isActive: Bool = true
    var stackable: Bool = false
    var priority: Int = 1

    var percentOff: Double = 0
    var amountOff: Double = 0

    // Type-specific
    var minDogs: Int = 2
    var packSize: Int = 10
    var packPrice: Double = 0
    var packExpiryDays: Int = 90
    var minBookings: Int = 5
    var minDurationMins: Int = 60
    var maxUsesPerClient: Int = 0 // 0 = unlimited

    var validFrom: Timestamp?
    var validUntil: Timestamp?
    var createdAt: Timestamp?
    var updatedAt: Timestamp?

    func appliesTo(_ serviceType: String) -> Bool {
        serviceTypes.isEmpty || serviceTypes.contains(serviceType)
    }

    var isCurrentlyValid: Bool {
        let now = Timestamp()
        if let from = validFrom, now.seconds < from.seconds { return false }
        if let until = validUntil, now.seconds > until.seconds { return false }
        return isActive
    }

    func calculateDiscount(basePrice: Double) -> Double {
        if percentOff > 0 { return basePrice * (percentOff / 100.0) }
        if amountOff > 0 { return min(amountOff, basePrice) }
        return 0
    }
}
