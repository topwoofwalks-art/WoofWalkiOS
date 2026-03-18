import Foundation

/// Service types offered by businesses, matching Android's ServiceType enum.
/// Raw values match the Firestore field values exactly.
enum BookingServiceType: String, Codable, CaseIterable {
    case walk = "WALK"
    case inSitting = "IN_SITTING"
    case outSitting = "OUT_SITTING"
    case boarding = "BOARDING"
    case grooming = "GROOMING"
    case meetGreet = "MEET_GREET"
    case petSitting = "PET_SITTING"
    case training = "TRAINING"
    case daycare = "DAYCARE"

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .walk: return "Walk"
        case .inSitting: return "In-Home Sitting"
        case .outSitting: return "Out Sitting"
        case .boarding: return "Boarding"
        case .grooming: return "Grooming"
        case .meetGreet: return "Meet & Greet"
        case .petSitting: return "Pet Sitting"
        case .training: return "Training"
        case .daycare: return "Daycare"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .inSitting: return "house.fill"
        case .outSitting: return "sun.max.fill"
        case .boarding: return "bed.double.fill"
        case .grooming: return "scissors"
        case .meetGreet: return "hand.wave.fill"
        case .petSitting: return "pawprint.fill"
        case .training: return "star.fill"
        case .daycare: return "sun.and.horizon.fill"
        }
    }

    /// Maximum number of dogs allowed for this service type
    var maxDogs: Int {
        switch self {
        case .walk: return 6
        case .inSitting: return 3
        case .outSitting: return 3
        case .boarding: return 2
        case .grooming: return 1
        case .meetGreet: return 4
        case .petSitting: return 3
        case .training: return 1
        case .daycare: return 8
        }
    }

    /// Default duration in minutes
    var defaultDuration: Int {
        switch self {
        case .walk: return 60
        case .inSitting: return 480
        case .outSitting: return 240
        case .boarding: return 1440
        case .grooming: return 90
        case .meetGreet: return 30
        case .petSitting: return 480
        case .training: return 60
        case .daycare: return 480
        }
    }

    /// Hex color string matching Android
    var colorHex: String {
        switch self {
        case .walk: return "#4CAF50"
        case .inSitting: return "#FF9800"
        case .outSitting: return "#FF5722"
        case .boarding: return "#2196F3"
        case .grooming: return "#9C27B0"
        case .meetGreet: return "#009688"
        case .petSitting: return "#607D8B"
        case .training: return "#795548"
        case .daycare: return "#E91E63"
        }
    }

    /// Parse from raw string, case-insensitive, defaulting to .walk
    static func from(rawValue: String) -> BookingServiceType {
        BookingServiceType(rawValue: rawValue.uppercased())
            ?? BookingServiceType.allCases.first { $0.rawValue.caseInsensitiveCompare(rawValue) == .orderedSame }
            ?? .walk
    }
}
