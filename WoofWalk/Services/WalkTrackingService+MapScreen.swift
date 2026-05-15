import Foundation
import CoreLocation

// MARK: - MapScreen Legacy Surface
//
// MapScreen and its extensions previously talked to an in-file toy
// `WalkTrackingViewModel` that exposed a naive jitter-filter (1-100 m
// distance gate, simple timer). That class has been deleted; MapScreen
// now binds directly to `WalkTrackingService.shared` so all walk tracking
// flows through the real Kalman + anchor-gate + pedometer-resume pipeline.
//
// This extension preserves the old call-site names (`isWalkActive`,
// `walkDistance`, `walkDuration`, `startWalk()`, `stopWalk()`,
// `updateLocation(_:)`) as a thin proxy onto `trackingState`. Putting the
// surface here keeps the main service file untouched.
//
// `updateLocation(_:)` is intentionally a no-op: the service subscribes
// to `LocationService.locationUpdatePublisher` itself, so the MapScreen
// `onChange(of: locationManager.location)` hand-off is no longer needed.
// The method is retained so MapScreen extensions keep compiling without
// touching the dozens of call sites.

@MainActor
extension WalkTrackingService {

    /// Whether the GPS pipeline is currently tracking a walk. Mirrors the
    /// old `WalkTrackingViewModel.isWalkActive` field MapScreen reads.
    var isWalkActive: Bool { trackingState.isTracking }

    /// Cumulative distance (metres) accepted by the GPS pipeline for the
    /// current walk. Drives the MapScreen recap and the stats HUD.
    var walkDistance: Double { trackingState.distanceMeters }

    /// Walk duration in seconds, surfaced as `TimeInterval` so call sites
    /// can pass it through Swift formatting helpers without a re-cast.
    var walkDuration: TimeInterval { TimeInterval(trackingState.durationSeconds) }

    /// Start tracking the current walk through the real GPS pipeline.
    /// Idempotent — the underlying `startTracking()` guards against a
    /// double-start so the existing MapScreen test commands stay safe.
    func startWalk() { startTracking() }

    /// Stop tracking and persist whatever the pipeline produced. The
    /// returned `LocalWalkRecord` is intentionally discarded here — the
    /// recap sheet is driven by `WalkTrackingService.trackingState` and
    /// `mapViewModel.walkDistance`, not the synchronous return value.
    func stopWalk() { _ = stopTracking() }

    /// Legacy hand-off retained for API compatibility with MapScreen's
    /// `onChange(of: locationManager.location)` block. The service gets
    /// its fixes via `LocationService.locationUpdatePublisher`, so this
    /// is a no-op — the underscore prefix silences the unused-arg lint.
    func updateLocation(_ location: CLLocationCoordinate2D) {
        _ = location
    }
}
