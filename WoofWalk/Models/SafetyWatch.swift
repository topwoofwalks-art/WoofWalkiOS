import Foundation

/// A live safety-watch session ("Watch Me"). Walker asks one or more
/// *guardians* to keep an eye on them while they walk. Mechanics overlap
/// with the social Live Share link (live GPS published to a public-token
/// URL) but the framing, page, and copy are deliberately separate so this
/// never reads as social show-off.
///
/// Lives in Firestore at /safety_watches/{id}. Reads happen via Cloud
/// Function gateway only (rules are tightened to deny direct client
/// access). Mirrors the Android `SafetyWatch` data class — keep field
/// names + types in sync.
struct SafetyWatch: Equatable, Identifiable {
    let id: String
    let sessionId: String
    let userId: String
    /// 32-char hex token (no hyphens) shared via deep-link / SMS so a
    /// guardian can open the live page without an account.
    let token: String

    let walkerFirstName: String
    let walkerNote: String

    /// Display names of guardians (mirrors guardianPhones / guardianUids
    /// order loosely — every guardian has a name; phones / uids may be
    /// partial).
    let guardianNames: [String]

    /// Phone numbers for non-WoofWalk guardians (sent the SMS / WhatsApp link).
    let guardianPhones: [String]

    /// WoofWalk friend uids — these guardians get the in-app push +
    /// alarm experience, not the SMS link.
    let guardianUids: [String]

    /// Subset of guardianUids who have explicitly tapped Accept.
    let guardianUidsAccepted: [String]

    /// Guardians who tapped Decline. Permanent skip for this watch.
    let declinedByUids: [String]

    /// Optional "expected back by" — drives the overdue-escalation cron.
    let expectedReturnAt: Int64

    var lastLat: Double
    var lastLng: Double
    var lastUpdatedAt: Int64

    var routePoints: [[String: Double]]

    var distanceMeters: Double
    var durationSec: Int64

    var lastCheckInAt: Int64

    var panicTriggeredAt: Int64
    var panicBroadcastAt: Int64
    var panicBroadcastCount: Int

    var status: String

    let createdAt: Int64
    let expiresAt: Int64
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        sessionId: String = "",
        userId: String = "",
        token: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
        walkerFirstName: String = "",
        walkerNote: String = "",
        guardianNames: [String] = [],
        guardianPhones: [String] = [],
        guardianUids: [String] = [],
        guardianUidsAccepted: [String] = [],
        declinedByUids: [String] = [],
        expectedReturnAt: Int64 = 0,
        lastLat: Double = 0.0,
        lastLng: Double = 0.0,
        lastUpdatedAt: Int64 = 0,
        routePoints: [[String: Double]] = [],
        distanceMeters: Double = 0.0,
        durationSec: Int64 = 0,
        lastCheckInAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        panicTriggeredAt: Int64 = 0,
        panicBroadcastAt: Int64 = 0,
        panicBroadcastCount: Int = 0,
        status: String = SafetyWatchStatus.active.rawValue,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        expiresAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000) + (8 * 3600 * 1000),
        isActive: Bool = true
    ) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.token = token
        self.walkerFirstName = walkerFirstName
        self.walkerNote = walkerNote
        self.guardianNames = guardianNames
        self.guardianPhones = guardianPhones
        self.guardianUids = guardianUids
        self.guardianUidsAccepted = guardianUidsAccepted
        self.declinedByUids = declinedByUids
        self.expectedReturnAt = expectedReturnAt
        self.lastLat = lastLat
        self.lastLng = lastLng
        self.lastUpdatedAt = lastUpdatedAt
        self.routePoints = routePoints
        self.distanceMeters = distanceMeters
        self.durationSec = durationSec
        self.lastCheckInAt = lastCheckInAt
        self.panicTriggeredAt = panicTriggeredAt
        self.panicBroadcastAt = panicBroadcastAt
        self.panicBroadcastCount = panicBroadcastCount
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isActive = isActive
    }
}

/// Lifecycle status of a SafetyWatch. Mirrors Android `SafetyWatchStatus`.
enum SafetyWatchStatus: String {
    case active = "ACTIVE"
    case overdue = "OVERDUE"
    case panic = "PANIC"
    case stationary = "STATIONARY"
    case arrived = "ARRIVED"
    case cancelled = "CANCELLED"
}

/// Per-guardian mirror doc at /users/{uid}/watched_walks/{watchId}. CF
/// maintained — clients never write here. Mirrors Android
/// `WatchedWalkSummary`.
struct WatchedWalkSummary: Identifiable, Equatable {
    var id: String { watchId }
    let watchId: String
    let walkerUid: String
    let walkerFirstName: String
    let status: String
    let createdAt: Int64
    let expiresAt: Int64
    let lastLat: Double
    let lastLng: Double
    let lastUpdatedAt: Int64
    let panicTriggeredAt: Int64
    /// True when the guardian tapped Decline.
    let declined: Bool
    /// True when the guardian has explicitly accepted (tap-through from the
    /// invite notification, or from the in-app picker confirmation).
    let accepted: Bool
}

/// Snapshot view returned by callable getters. Subset of SafetyWatch
/// fields — guardian uid + walker uid are redacted server-side.
struct SafetyWatchSnapshot: Equatable {
    let id: String
    let walkerFirstName: String
    let walkerNote: String
    let lastLat: Double
    let lastLng: Double
    let lastUpdatedAt: Int64
    let routePoints: [[String: Double]]
    let distanceMeters: Double
    let durationSec: Int64
    let lastCheckInAt: Int64
    let panicTriggeredAt: Int64
    let status: String
    let expectedReturnAt: Int64
    let isOwner: Bool
    let isAccepted: Bool
    let isDeclined: Bool

    static func fromMap(_ m: [String: Any]) -> SafetyWatchSnapshot {
        let rawPoints = (m["routePoints"] as? [[String: Any]]) ?? []
        let points: [[String: Double]] = rawPoints.compactMap { pm in
            guard let lat = (pm["lat"] as? NSNumber)?.doubleValue,
                  let lng = (pm["lng"] as? NSNumber)?.doubleValue else { return nil }
            return ["lat": lat, "lng": lng]
        }
        return SafetyWatchSnapshot(
            id: m["id"] as? String ?? "",
            walkerFirstName: m["walkerFirstName"] as? String ?? "",
            walkerNote: m["walkerNote"] as? String ?? "",
            lastLat: (m["lastLat"] as? NSNumber)?.doubleValue ?? 0,
            lastLng: (m["lastLng"] as? NSNumber)?.doubleValue ?? 0,
            lastUpdatedAt: (m["lastUpdatedAt"] as? NSNumber)?.int64Value ?? 0,
            routePoints: points,
            distanceMeters: (m["distanceMeters"] as? NSNumber)?.doubleValue ?? 0,
            durationSec: (m["durationSec"] as? NSNumber)?.int64Value ?? 0,
            lastCheckInAt: (m["lastCheckInAt"] as? NSNumber)?.int64Value ?? 0,
            panicTriggeredAt: (m["panicTriggeredAt"] as? NSNumber)?.int64Value ?? 0,
            status: m["status"] as? String ?? "ACTIVE",
            expectedReturnAt: (m["expectedReturnAt"] as? NSNumber)?.int64Value ?? 0,
            isOwner: m["isOwner"] as? Bool ?? false,
            isAccepted: m["isAccepted"] as? Bool ?? false,
            isDeclined: m["isDeclined"] as? Bool ?? false
        )
    }
}
