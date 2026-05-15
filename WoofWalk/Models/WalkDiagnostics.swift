import Foundation
import FirebaseFirestore

/// Per-walk GPS pipeline diagnostic record. Written to
/// `/users/{uid}/walk_diagnostics/{walkId}` once at the end of each walk
/// (and again on background-during-walk so we have data even if the OS
/// kills the app before stop).
///
/// Forensic-only: when a user reports a bad walk we look up this doc to
/// see which gate killed the pipeline (filter rejection, step-gate, drift
/// guard, permission revoke, service kill, etc.) instead of guessing from
/// screenshots.
///
/// Schema is intentionally flat — Firestore queries over diagnostics
/// (e.g. "give me all walks where serviceKillCount > 0") become trivial.
///
/// Mirrors Android `data/model/WalkDiagnostics.kt`. Field names match the
/// Android side so a single CF / portal admin tool can join the two.
struct WalkDiagnostics: Codable {
    // ── Identity ────────────────────────────────────────────────
    var walkId: String = ""
    var userId: String = ""
    /// Wall-clock millisecond timestamp when the walk started.
    var startedAtMs: Int64 = 0
    /// Wall-clock millisecond timestamp when the walk ended (or the
    /// snapshot was taken, for mid-walk background writes).
    var endedAtMs: Int64 = 0

    // ── Device context ──────────────────────────────────────────
    var deviceManufacturer: String = "Apple"
    var deviceModel: String = ""
    /// iOS major version int (e.g. 17 for iOS 17.x).
    var iosMajorVersion: Int = 0
    /// Full iOS version string (e.g. "17.4.1").
    var iosVersion: String = ""
    var appVersionName: String = ""
    var appVersionCode: Int = 0

    // ── Permission + power state at walk start ──────────────────
    /// `whenInUse` or stronger granted at start.
    var foregroundLocationAtStart: Bool = false
    /// `always` authorisation granted at start.
    var backgroundLocationAtStart: Bool = false
    /// Precise location enabled (vs reduced accuracy).
    var preciseLocationAtStart: Bool = false
    /// `UIDevice.current.batteryState != .unknown` — proxy for "we can
    /// observe battery state". The Android equivalent is the
    /// PowerSave-mode-at-start flag.
    var lowPowerModeAtStart: Bool = false
    /// Motion (CMPedometer/CMMotionActivityManager) authorisation
    /// granted. Without this the step-gate falls back to "always
    /// accept".
    var motionPermissionAtStart: Bool = false

    // ── Timeline counters ───────────────────────────────────────
    /// Total location callbacks CoreLocation delivered.
    var fixesReceived: Int = 0
    /// Fixes that survived all gates and updated tracking state.
    var fixesAccepted: Int = 0
    /// Fixes rejected, broken down by reason. Keys come from
    /// `WalkDiagnostics.RejectionReason.rawValue`. Stored as a flat
    /// `[String: Int]` so a single Firestore query can pull it.
    var fixesRejected: [String: Int] = [:]

    /// Convenience accessor for total rejection count.
    var fixesRejectedTotal: Int {
        fixesRejected.values.reduce(0, +)
    }

    /// Wall-clock samples of "are we in dead-reckoning mode now" — the
    /// service polls this every accepted fix. Stored as a bool array so
    /// we can replay the DR-mode timeline post-walk. Capped at ~1000
    /// entries to keep doc size bounded.
    var drModeHistory: [Bool] = []

    /// True if location permission was revoked mid-walk.
    var permissionRevokedMidWalk: Bool = false
    /// True if Settings → Privacy → Location Services was turned off
    /// mid-walk.
    var locationServicesOffMidWalk: Bool = false
    /// True if the user enabled Low Power Mode mid-walk.
    var lowPowerModeEnteredMidWalk: Bool = false

    /// How many times Android-style auto-pause triggered.
    var autoPauseTriggers: Int = 0
    /// How many times the user manually paused or resumed.
    var manualPauseToggles: Int = 0

    /// Count of times the OS killed-and-restarted the walk service
    /// during this walk (detected by `WalkBootRecovery` finding an
    /// in-flight marker for the same walkId on cold launch).
    var serviceKillCount: Int = 0
    /// Count of times the watchdog recovered the pipeline from a
    /// stalled-but-alive state (e.g. background-grace-period kicked us
    /// awake or stale-fix gate reset the GPS chip).
    var watchdogRecoveryCount: Int = 0

    /// Snapshot of permissions captured at end-of-walk. Lets us spot
    /// permission flicker — start=true, end=false signals a mid-walk
    /// revoke even if the live `permissionRevokedMidWalk` flag missed
    /// it.
    var permissionsSnapshot: [String: Bool] = [:]

    // ── Distance / step / stride metrics ────────────────────────
    /// Total distance accumulated by the live pipeline.
    var totalDistanceMeters: Double = 0.0
    /// Distance after `GpsPostProcessor` cleaning at stop. May be
    /// significantly less than `totalDistanceMeters` if the live track
    /// had jitter.
    var finalDistanceMeters: Double = 0.0
    /// Wall-clock walk duration in seconds.
    var wallClockDurationSec: Int = 0
    /// Track-point count actually retained post-process.
    var trackPointCount: Int = 0
    /// Cumulative elevation gain in meters.
    var elevationGainMeters: Double = 0.0

    // ── Server-side timestamps + TTL ────────────────────────────
    /// Server-side write timestamp. NOT encoded here — the write path
    /// in `WalkTrackingService.shipDiagnosticsSnapshot` merges a
    /// `FieldValue.serverTimestamp()` sentinel directly into the
    /// Firestore payload dict so the server clock wins. When reading
    /// back the doc decodes into a `Timestamp` like any other.
    var serverTimestamp: Timestamp?

    /// Firestore TTL field. Set to (startedAtMs + 90 days) on write so
    /// the platform auto-deletes the doc after 90 days. Mirrors
    /// Android commit 96c8ab3. Enable the TTL policy on a fresh
    /// project with:
    ///
    ///     gcloud firestore fields ttls update expiresAt \
    ///       --collection-group=walk_diagnostics \
    ///       --enable-ttl \
    ///       --project=woofwalk-e0231
    var expiresAt: Timestamp?

    /// Fix-rejection reasons. RawValue strings are the Firestore map
    /// keys — keep stable across versions so historical docs decode.
    enum RejectionReason: String, CaseIterable {
        /// `CLLocation` older than `maxFixAgeSeconds` (stale fix gate).
        case stale = "stale"
        /// `GPSFilterPipeline.process` returned nil (Kalman / accuracy).
        case filter = "filter"
        /// Step-validation gate: GPS moved but pedometer reported 0 steps.
        case stepGate = "stepGate"
        /// Stationary-drift guard: motion service confident user is
        /// standing still + fix more than 0.5 m from anchor.
        case stationaryGuard = "stationaryGuard"
        /// Catch-all for future reasons that haven't been enumerated
        /// yet. Should stay at 0 in steady state.
        case other = "other"
    }
}

extension WalkDiagnostics {
    /// Increment a rejection counter by reason. Safe across all
    /// RejectionReason cases.
    mutating func recordRejection(_ reason: RejectionReason) {
        fixesRejected[reason.rawValue, default: 0] += 1
    }
}
