import Foundation
import CoreLocation

// MARK: - Walk Console Models
//
// 1:1 port of the Android `WalkConsoleUiState.kt` data classes used by
// the business walker mode. Names + field shapes match Android so the
// downstream Firestore writes / live-share CF payloads stay parity-safe.
//
// All types are namespaced with `WalkConsole` / `BWS` (BusinessWalkSession)
// prefixes to avoid collision with the consumer-side `WalkSession` /
// `WalkPhoto` etc. that already live in the iOS codebase.
//
// Source of truth: `app/src/main/java/com/woofwalk/ui/business/walker/WalkConsoleUiState.kt`
//                  `app/src/main/java/com/woofwalk/ui/business/walker/WalkConsoleViewModel.kt`

/// Status of an active walk session.
enum BWSWalkStatus: String, Codable {
    case pending = "PENDING"
    case inProgress = "IN_PROGRESS"
    case paused = "PAUSED"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
}

/// Types of incidents that can occur during a walk. Raw values match
/// Android's `IncidentType` enum constants (used as Firestore strings).
enum WalkIncidentType: String, CaseIterable, Codable {
    case aggressiveDogEncounter = "AGGRESSIVE_DOG_ENCOUNTER"
    case injury = "INJURY"
    case lostTemporarily = "LOST_TEMPORARILY"
    case bathroomAccident = "BATHROOM_ACCIDENT"
    case refusedToWalk = "REFUSED_TO_WALK"
    case weatherIssue = "WEATHER_ISSUE"
    case equipmentFailure = "EQUIPMENT_FAILURE"
    case other = "OTHER"

    /// Human-readable display name (matches Android's
    /// `name.replace("_", " ")` rendering).
    var displayName: String {
        switch self {
        case .aggressiveDogEncounter: return "Aggressive Dog Encounter"
        case .injury: return "Injury"
        case .lostTemporarily: return "Lost Temporarily"
        case .bathroomAccident: return "Bathroom Accident"
        case .refusedToWalk: return "Refused To Walk"
        case .weatherIssue: return "Weather Issue"
        case .equipmentFailure: return "Equipment Failure"
        case .other: return "Other"
        }
    }
}

/// Severity levels for incidents. HIGH and CRITICAL trigger client
/// notifications via the BusinessWalkSessionRepository.
enum WalkIncidentSeverity: String, CaseIterable, Codable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"

    var displayName: String { rawValue.capitalized }
}

/// Live stats for the active walk. Updated every second by the
/// stats-tick timer + on each accepted GPS fix.
struct WalkConsoleLiveStats: Equatable {
    /// Cumulative distance in metres.
    var distance: Double = 0
    /// Elapsed seconds.
    var duration: Int = 0
    /// Pace in min/km. `nil` until enough distance has accumulated.
    var pace: Double? = nil

    func formattedDistance() -> String {
        FormatUtils.formatDistance(distance)
    }

    func formattedDuration() -> String {
        FormatUtils.formatDurationCompact(duration)
    }

    func formattedPace() -> String {
        guard let pace = pace else { return "--:--" }
        return FormatUtils.formatPace(pace)
    }
}

/// One accepted GPS point on the active walk's polyline.
struct WalkConsoleRoutePoint: Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Int64
    let accuracy: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Active walk session — local mirror of the Firestore `walk_sessions/{id}` doc.
struct BusinessWalkSessionState: Equatable {
    let id: String
    /// Primary booking id; for group walks, set to the first id in `bookingIds`.
    let bookingId: String?
    let dogIds: [String]
    let startedAt: Int64
    var status: BWSWalkStatus
    let plannedWalkId: String?
    var routePoints: [WalkConsoleRoutePoint]
    /// Walker's org id — copied through from booking.orgId at session start.
    let orgId: String

    init(
        id: String,
        bookingId: String?,
        dogIds: [String],
        startedAt: Int64,
        status: BWSWalkStatus,
        plannedWalkId: String? = nil,
        routePoints: [WalkConsoleRoutePoint] = [],
        orgId: String = ""
    ) {
        self.id = id
        self.bookingId = bookingId
        self.dogIds = dogIds
        self.startedAt = startedAt
        self.status = status
        self.plannedWalkId = plannedWalkId
        self.routePoints = routePoints
        self.orgId = orgId
    }
}

/// Photo captured during a walk. `photoUrl` is local file URI until the
/// upload completes, then swapped to the Storage download URL.
struct WalkConsolePhoto: Identifiable, Equatable {
    let id: String
    let sessionId: String
    var photoUrl: String
    var thumbnailUrl: String?
    let caption: String?
    let timestamp: Int64
    let latitude: Double?
    let longitude: Double?
}

/// Incident logged during a walk. HIGH / CRITICAL severities push a
/// client notification via the repository.
struct WalkConsoleIncident: Identifiable, Equatable {
    let id: String
    let sessionId: String
    let type: WalkIncidentType
    let severity: WalkIncidentSeverity
    let notes: String
    let timestamp: Int64
    let latitude: Double?
    let longitude: Double?
    let photoUrl: String?

    init(
        id: String,
        sessionId: String,
        type: WalkIncidentType,
        severity: WalkIncidentSeverity,
        notes: String,
        timestamp: Int64,
        latitude: Double? = nil,
        longitude: Double? = nil,
        photoUrl: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.type = type
        self.severity = severity
        self.notes = notes
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.photoUrl = photoUrl
    }
}

/// Summary returned to the caller when the walk ends. Drives the
/// post-walk completion screen.
struct WalkConsoleSummary: Equatable {
    let sessionId: String
    let bookingId: String?
    let duration: Int
    let distance: Double
    let photoCount: Int
    let incidentCount: Int
}

/// Per-client send target for the share sheet. One row per booking
/// covered by the active live-share. Empty for solo walks (which use
/// the single-URL Copy / Send buttons instead).
struct BookingShareTarget: Identifiable, Equatable {
    let bookingId: String
    let clientName: String
    let clientPhone: String?
    let dogNames: [String]
    let perClientUrl: String

    var id: String { bookingId }
}

/// Pre-walk client brief — surfaces address / phone / key code /
/// special instructions for each booking BEFORE the walker hits Start.
/// Loaded from `bookings/{id}` at screen entry; best-effort across
/// schema variants. Mirrors Android `ClientBrief` data class.
struct ClientBrief: Identifiable, Equatable {
    let bookingId: String
    let clientName: String
    let clientPhone: String?
    let address: String?
    let keyCode: String?
    let specialInstructions: String?
    let dogNames: [String]

    var id: String { bookingId }
}

/// Lightweight dog projection for the check-in strip. Backed by the
/// `dogs/{id}` doc; we only render name + photo + id so a minimal
/// projection is sufficient.
struct WalkConsoleDog: Identifiable, Equatable {
    let id: String
    let name: String
    let photoUrl: String?
    let breed: String?
}
