import SwiftUI

/// Booking status states matching Android's BookingStatus enum.
/// Raw values match the Firestore field values exactly.
enum BookingStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    /// Card-payment booking that hasn't been paid yet. Auto-cancels after
    /// the org's autoCancelWindowHours if no payment lands. Server sets
    /// this on createClientBooking when paymentMethod=='card'. Cash
    /// bookings skip this status entirely (go straight to PENDING).
    case awaitingPayment = "AWAITING_PAYMENT"
    case confirmed = "CONFIRMED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
    case rejected = "REJECTED"
    case noShow = "NO_SHOW"

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .awaitingPayment: return "Awaiting Payment"
        case .confirmed: return "Confirmed"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .rejected: return "Rejected"
        case .noShow: return "No Show"
        }
    }

    /// Status color for UI display
    var color: Color {
        switch self {
        case .pending: return .orange
        case .awaitingPayment: return Color(red: 0.70, green: 0.42, blue: 0.0)
        case .confirmed: return .blue
        case .inProgress: return .green
        case .completed: return .gray
        case .cancelled: return .red
        case .rejected: return Color(red: 0.6, green: 0.0, blue: 0.0)
        case .noShow: return .purple
        }
    }

    /// Whether this status represents an active booking
    var isActive: Bool {
        switch self {
        case .pending, .awaitingPayment, .confirmed, .inProgress:
            return true
        case .completed, .cancelled, .rejected, .noShow:
            return false
        }
    }

    /// Valid status transitions from this state
    var validTransitions: [BookingStatus] {
        switch self {
        case .pending:
            return [.confirmed, .rejected, .cancelled]
        case .awaitingPayment:
            return [.confirmed, .cancelled]
        case .confirmed:
            return [.inProgress, .cancelled]
        case .inProgress:
            return [.completed, .cancelled]
        case .completed, .cancelled, .rejected, .noShow:
            return []
        }
    }

    /// Parse from raw string, case-insensitive, defaulting to .pending
    static func from(rawValue: String) -> BookingStatus {
        BookingStatus(rawValue: rawValue.uppercased())
            ?? BookingStatus.allCases.first { $0.rawValue.caseInsensitiveCompare(rawValue) == .orderedSame }
            ?? .pending
    }
}
