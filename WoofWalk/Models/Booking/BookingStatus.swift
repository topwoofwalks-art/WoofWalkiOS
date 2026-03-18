import SwiftUI

/// Booking status states matching Android's BookingStatus enum.
/// Raw values match the Firestore field values exactly.
enum BookingStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
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
        case .pending, .confirmed, .inProgress:
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
