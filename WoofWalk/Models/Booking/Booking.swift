import Foundation
import FirebaseFirestore

/// Represents a booking for a pet service (walk, grooming, sitting, boarding).
/// Matches Android Firestore structure exactly.
struct Booking: Identifiable, Codable {
    @DocumentID var id: String?
    var clientId: String
    var clientName: String
    var businessId: String
    var orgId: String
    var organizationId: String
    var dogName: String
    var dogBreed: String?
    var serviceType: String  // Raw Firestore value; use serviceTypeEnum for typed access
    var startTime: Int64
    var endTime: Int64
    var status: String       // Raw Firestore value; use statusEnum for typed access
    var location: String
    var notes: String?
    var price: Double
    var isPaid: Bool
    var assignedTo: String?
    var clientPhone: String?
    var clientEmail: String?
    var clientAvatar: String?
    var dogAvatar: String?
    var petId: String?
    var specialInstructions: String?
    var specialRequirements: String?
    var cancellationReason: String?
    var createdAt: Int64
    var updatedAt: Int64

    // MARK: - Recurring Bookings

    /// Server-side series identity stamped on every occurrence in a
    /// recurring series. Null for one-off bookings. The recurrence rule
    /// itself lives at `booking_series/{recurrenceGroupId}` (CF-only,
    /// clients never read it directly). Drives the recurring badge on
    /// the bookings list and the cancel-scope dialog on detail.
    var recurrenceGroupId: String?
    /// 0-based position within the series (0 = first occurrence). Null
    /// for one-off bookings.
    var recurrenceOccurrenceIndex: Int?
    /// Frequency snapshot — `DAILY` / `WEEKLY` / `BIWEEKLY` / `MONTHLY`.
    /// Stored as a string so the badge renders without reading
    /// `booking_series`. Null for one-off bookings.
    var recurrenceFrequency: String?
    /// Interval (every N units, e.g. 1 = every week, 2 = every other
    /// week). Null for one-off bookings.
    var recurrenceInterval: Int?

    // MARK: - Service Selection (Phase 1)

    /// ID of the selected variant (walk duration, sitting visit type, etc.)
    var selectedVariantId: String?
    /// Display name of the selected variant
    var selectedVariantName: String?
    /// ID of the selected package (grooming, boarding, daycare, training programme)
    var selectedPackageId: String?
    /// Display name of the selected package
    var selectedPackageName: String?
    /// Training specialism ID, if applicable
    var specialism: String?
    /// Dog size for grooming price tier
    var dogSize: String?
    /// IDs of selected grooming add-ons
    var selectedAddOns: [String]?
    /// Final computed price from service config
    var computedPrice: Double?

    // MARK: - Payment

    /// "card" (default — pay through Stripe at booking time) or "cash"
    /// (pay the provider in person on the day). Drives the booking-detail
    /// payment card UX: card bookings in AWAITING_PAYMENT show a Pay-Now
    /// CTA, cash bookings show a "set to pay in cash — switch to card?"
    /// confirmation card. Server-set on createClientBooking; switched
    /// later via the switchPaymentMethodToCard Cloud Function.
    var paymentMethod: String?
    /// Wall-clock millisecond cutoff for the AWAITING_PAYMENT auto-cancel
    /// sweep. Snapshotted onto the booking at create-time so later
    /// changes to the org's autoCancelWindowHours don't retroactively
    /// cancel in-flight bookings.
    var autoCancelAtMillis: Int64?

    // MARK: - Computed Properties

    /// Typed payment method (defaults to .card if missing — matches
    /// Android's behaviour for legacy bookings created before the field
    /// was added).
    var paymentMethodEnum: BookingPaymentMethod {
        BookingPaymentMethod(rawValue: (paymentMethod ?? "card").lowercased()) ?? .card
    }

    /// Typed booking status
    var statusEnum: BookingStatus {
        BookingStatus.from(rawValue: status)
    }

    /// Typed service type
    var serviceTypeEnum: BookingServiceType {
        BookingServiceType.from(rawValue: serviceType)
    }

    /// Get organization ID from either orgId or organizationId field
    var organizationIdCompat: String {
        orgId.isEmpty ? organizationId : orgId
    }

    /// Start time as Date
    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startTime) / 1000.0)
    }

    /// End time as Date
    var endDate: Date {
        Date(timeIntervalSince1970: TimeInterval(endTime) / 1000.0)
    }

    /// Duration in minutes
    var durationMinutes: Int {
        Int((endTime - startTime) / (1000 * 60))
    }

    // MARK: - Init

    init(
        id: String? = nil,
        clientId: String = "",
        clientName: String = "",
        businessId: String = "",
        orgId: String = "",
        organizationId: String = "",
        dogName: String = "",
        dogBreed: String? = nil,
        serviceType: String = BookingServiceType.walk.rawValue,
        startTime: Int64 = 0,
        endTime: Int64 = 0,
        status: String = BookingStatus.pending.rawValue,
        location: String = "",
        notes: String? = nil,
        price: Double = 0.0,
        isPaid: Bool = false,
        assignedTo: String? = nil,
        clientPhone: String? = nil,
        clientEmail: String? = nil,
        clientAvatar: String? = nil,
        dogAvatar: String? = nil,
        petId: String? = nil,
        specialInstructions: String? = nil,
        specialRequirements: String? = nil,
        cancellationReason: String? = nil,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        recurrenceGroupId: String? = nil,
        recurrenceOccurrenceIndex: Int? = nil,
        recurrenceFrequency: String? = nil,
        recurrenceInterval: Int? = nil,
        selectedVariantId: String? = nil,
        selectedVariantName: String? = nil,
        selectedPackageId: String? = nil,
        selectedPackageName: String? = nil,
        specialism: String? = nil,
        dogSize: String? = nil,
        selectedAddOns: [String]? = nil,
        computedPrice: Double? = nil,
        paymentMethod: String? = nil,
        autoCancelAtMillis: Int64? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.clientName = clientName
        self.businessId = businessId
        self.orgId = orgId
        self.organizationId = organizationId
        self.dogName = dogName
        self.dogBreed = dogBreed
        self.serviceType = serviceType
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.location = location
        self.notes = notes
        self.price = price
        self.isPaid = isPaid
        self.assignedTo = assignedTo
        self.clientPhone = clientPhone
        self.clientEmail = clientEmail
        self.clientAvatar = clientAvatar
        self.dogAvatar = dogAvatar
        self.petId = petId
        self.specialInstructions = specialInstructions
        self.specialRequirements = specialRequirements
        self.cancellationReason = cancellationReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recurrenceGroupId = recurrenceGroupId
        self.recurrenceOccurrenceIndex = recurrenceOccurrenceIndex
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceInterval = recurrenceInterval
        self.selectedVariantId = selectedVariantId
        self.selectedVariantName = selectedVariantName
        self.selectedPackageId = selectedPackageId
        self.selectedPackageName = selectedPackageName
        self.specialism = specialism
        self.dogSize = dogSize
        self.selectedAddOns = selectedAddOns
        self.computedPrice = computedPrice
        self.paymentMethod = paymentMethod
        self.autoCancelAtMillis = autoCancelAtMillis
    }

    // MARK: - Recurring Helpers

    /// True when this booking is part of a recurring series. Drives the
    /// recurring badge on the bookings list and the scoped cancel dialog
    /// on the detail screen.
    var isRecurring: Bool {
        guard let groupId = recurrenceGroupId else { return false }
        return !groupId.isEmpty
    }

    /// Short human label for the recurring badge — "Daily", "Weekly",
    /// "Every 2 weeks", "Monthly". Falls back to "Repeats" when the
    /// snapshot field is missing on legacy occurrences. Nil for one-off
    /// bookings (caller suppresses the badge).
    var recurrenceBadgeLabel: String? {
        guard isRecurring else { return nil }
        switch recurrenceFrequency?.uppercased() {
        case "DAILY": return "Daily"
        case "WEEKLY": return "Weekly"
        case "BIWEEKLY": return "Every 2 weeks"
        case "MONTHLY": return "Monthly"
        default: return "Repeats"
        }
    }

    // MARK: - Static Helpers

    /// Convert a Date to epoch milliseconds (matching Android's Long format)
    static func toEpochMs(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }
}

/// Booking payment method, mirrored from Android.
enum BookingPaymentMethod: String, Codable, CaseIterable {
    case card
    case cash
}
