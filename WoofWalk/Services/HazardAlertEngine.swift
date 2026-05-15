import Foundation
import Combine
import CoreLocation
import UIKit

/// Proximity engine that fires `HazardAlertBanner`-bound alerts when the
/// user walks within ~50 m of an active hazard. Mirrors Android's
/// `app/src/main/java/com/woofwalk/ui/map/HazardAlertSystem.kt` proximity
/// trigger — banner UI was already shipped on iOS (`HazardAlertBanner`,
/// `HazardAlertBannerContainer`) but nothing was firing it as a single-shot
/// "you just walked into a hazard zone" event.
///
/// Behaviour:
///  - Subscribes to `LocationService.shared.locationUpdatePublisher`.
///  - On each fix, computes `CLLocation.distance(from:)` to every hazard.
///  - First hazard inside `proximityRadiusMeters` becomes `activeAlert`.
///  - Per-hazard 5-minute dedup window keyed by hazard id keeps us from
///    re-buzzing the user every GPS tick while they're still in the zone.
///  - Plays a single short haptic when the alert fires (`.warning`
///    notification feedback — distinct from a tap and audible-feedback off).
///  - `dismissAlert()` clears the banner; `stop()` tears down the
///    subscription (call from `.onDisappear`).
@MainActor
final class HazardAlertEngine: ObservableObject {
    /// Banner-bound active alert. Nil = no banner showing.
    @Published var activeAlert: HazardReport?

    /// Distance threshold for "you are in this hazard zone". Matches the
    /// Android default in `HazardAlertSystem.kt` (50 m).
    let proximityRadiusMeters: CLLocationDistance = 50.0

    /// Dedup window per hazard id. Once we alert for hazard X, we don't
    /// alert for X again for this many seconds (regardless of whether the
    /// user dismissed it or it auto-cleared).
    let dedupWindow: TimeInterval = 5 * 60

    private var hazards: [HazardReport] = []
    private var lastAlertedAt: [String: Date] = [:]
    private var locationSubscription: AnyCancellable?

    init() {}

    /// Begin watching for proximity alerts against the supplied hazard
    /// set. Safe to call again to update the hazard list — the
    /// subscription is reused.
    func start(hazards: [HazardReport]) {
        self.hazards = hazards.filter { !$0.isExpired }

        guard locationSubscription == nil else { return }

        locationSubscription = LocationService.shared.locationUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.evaluate(at: update.coordinate)
            }
    }

    /// Update the hazard set in-place without tearing the subscription
    /// down. Called when the map's hazard listener fires a new snapshot.
    func updateHazards(_ hazards: [HazardReport]) {
        self.hazards = hazards.filter { !$0.isExpired }
    }

    /// Dismiss the visible banner without affecting the dedup window —
    /// dismissing now still suppresses re-fires for the same hazard for
    /// `dedupWindow` seconds.
    func dismissAlert() {
        activeAlert = nil
    }

    /// Tear down the location subscription and clear state. Call this
    /// from the MapScreen's `.onDisappear` so we don't keep the
    /// LocationService publisher retained across navigation.
    func stop() {
        locationSubscription?.cancel()
        locationSubscription = nil
        activeAlert = nil
    }

    // MARK: - Internals

    private func evaluate(at coordinate: CLLocationCoordinate2D) {
        // Already showing a banner — let the user dismiss before we
        // consider firing another. The dedup map still prevents the same
        // hazard from re-firing immediately after dismiss.
        guard activeAlert == nil else { return }

        let userLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let now = Date()

        // Pick the closest non-expired hazard within proximityRadiusMeters
        // that isn't currently in its dedup window.
        let candidate = hazards
            .compactMap { hazard -> (HazardReport, CLLocationDistance)? in
                guard let id = hazard.id else { return nil }
                if let last = lastAlertedAt[id], now.timeIntervalSince(last) < dedupWindow {
                    return nil
                }
                let hazardLoc = CLLocation(latitude: hazard.lat, longitude: hazard.lng)
                let dist = userLoc.distance(from: hazardLoc)
                guard dist <= proximityRadiusMeters else { return nil }
                return (hazard, dist)
            }
            .min { $0.1 < $1.1 }?
            .0

        guard let hazard = candidate, let id = hazard.id else { return }

        lastAlertedAt[id] = now
        activeAlert = hazard
        fireHaptic()
    }

    private func fireHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}
