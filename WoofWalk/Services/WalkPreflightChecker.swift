import Foundation
import CoreLocation
import UIKit

/// Pre-walk-start safety net. Mirrors Android
/// `app/src/main/java/com/woofwalk/service/WalkPreflightChecker.kt`. iOS
/// previously had no preflight at all — `WalkTrackingService.startWalk()`
/// was called regardless of whether location was authorised, services
/// were on, or the device was in low-power mode. That left users with
/// silent 0-point recap screens when the OS refused to deliver fixes.
///
/// Failure surfaces are split into two tiers:
///
/// - **Blockers** (`canStart == false`) — hard reasons the walk would
///   record nothing. Surface as the primary content in
///   `WalkPreflightDialog` with a "Open Settings" action.
/// - **Warnings** — soft signals. Walk can still start but accuracy /
///   duration is at risk. Surface in a subordinate section with a
///   "Walk anyway" override.
struct WalkPreflightCheck {
    /// True iff there are zero blockers. Warnings are advisory and do
    /// not flip this to false.
    let canStart: Bool
    let blockers: [Blocker]
    let warnings: [Warning]

    /// Hard failures. Walk should not proceed.
    enum Blocker: Equatable, Hashable {
        /// `CLAuthorizationStatus` is `.denied` or `.restricted`. User
        /// must change permission in Settings — we cannot re-prompt
        /// once they've denied once on iOS.
        case locationPermissionDenied
        /// `CLLocationManager.locationServicesEnabled() == false` —
        /// system-wide Location Services switch is off. Send to
        /// `LocationServices` settings pane.
        case locationServicesOff
    }

    /// Soft signals. Walk can start but quality / duration is at risk.
    enum Warning: Equatable, Hashable {
        /// Permission is `.authorizedWhenInUse`, not `.authorizedAlways`.
        /// Foreground walks still work; background-resumed walks
        /// (screen off) will lose updates beyond ~10 minutes.
        case locationPermissionWhenInUseOnly
        /// `ProcessInfo.processInfo.isLowPowerModeEnabled == true`. iOS
        /// reduces background refresh and may down-sample GPS. The
        /// Android equivalent is `PowerManager.isPowerSaveMode`.
        case lowPowerMode
        /// Battery < 15 % and not charging. Pair with `deviceUnplugged`
        /// to nudge the user to plug in for long walks.
        case batteryUnder15
        /// Device is on battery (not plugged in) and below 50 %. Just a
        /// gentle hint when the user is about to start a long walk.
        case deviceUnplugged
    }

    /// Gather every preflight signal. Runs `CLLocationManager` checks on
    /// a detached task because `locationServicesEnabled()` blocks on
    /// iOS 14+ if called on the main thread. The await guarantees we
    /// don't trigger the Xcode warning users have hit in 7.9.x builds.
    static func check() async -> WalkPreflightCheck {
        let authStatus = await Task.detached { () -> CLAuthorizationStatus in
            let manager = CLLocationManager()
            return manager.authorizationStatus
        }.value

        let servicesEnabled = await Task.detached { () -> Bool in
            CLLocationManager.locationServicesEnabled()
        }.value

        var blockers: [Blocker] = []
        var warnings: [Warning] = []

        // Authorization checks.
        switch authStatus {
        case .denied, .restricted:
            blockers.append(.locationPermissionDenied)
        case .authorizedWhenInUse:
            warnings.append(.locationPermissionWhenInUseOnly)
        case .notDetermined, .authorizedAlways:
            break
        @unknown default:
            break
        }

        if !servicesEnabled {
            blockers.append(.locationServicesOff)
        }

        // Power / battery checks.
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            warnings.append(.lowPowerMode)
        }

        // Battery sampling needs monitoring enabled. We don't disable
        // it after — other services (LocationService) read it too.
        await MainActor.run {
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
        let level = await MainActor.run { UIDevice.current.batteryLevel }
        let batteryState = await MainActor.run { UIDevice.current.batteryState }

        // batteryLevel returns -1.0 when monitoring isn't ready or in
        // simulator — only act on positive samples.
        if level >= 0 {
            let unplugged = (batteryState == .unplugged || batteryState == .unknown)
            if level < 0.15 && unplugged {
                warnings.append(.batteryUnder15)
            } else if level < 0.50 && unplugged {
                warnings.append(.deviceUnplugged)
            }
        }

        return WalkPreflightCheck(
            canStart: blockers.isEmpty,
            blockers: blockers,
            warnings: warnings
        )
    }
}

// MARK: - User-facing copy

extension WalkPreflightCheck.Blocker {
    var title: String {
        switch self {
        case .locationPermissionDenied: return "Location permission needed"
        case .locationServicesOff: return "Location Services are off"
        }
    }

    var message: String {
        switch self {
        case .locationPermissionDenied:
            return "WoofWalk needs location access to track your walk. Open Settings to allow it."
        case .locationServicesOff:
            return "Location Services are turned off in your iPhone's settings. Turn them on to record a walk."
        }
    }

    var systemImage: String {
        switch self {
        case .locationPermissionDenied: return "location.slash.fill"
        case .locationServicesOff: return "location.slash"
        }
    }
}

extension WalkPreflightCheck.Warning {
    var title: String {
        switch self {
        case .locationPermissionWhenInUseOnly: return "Background tracking limited"
        case .lowPowerMode: return "Low Power Mode is on"
        case .batteryUnder15: return "Battery below 15%"
        case .deviceUnplugged: return "Battery below 50%"
        }
    }

    var message: String {
        switch self {
        case .locationPermissionWhenInUseOnly:
            return "WoofWalk only has permission to use your location while open. Your walk may stop tracking if you lock the phone for long."
        case .lowPowerMode:
            return "Low Power Mode throttles GPS — your track may lose accuracy. Consider switching it off in Settings."
        case .batteryUnder15:
            return "Your battery is low. A long walk may drain it before you finish."
        case .deviceUnplugged:
            return "Long walks drain the battery. You might want to top up before you head out."
        }
    }

    var systemImage: String {
        switch self {
        case .locationPermissionWhenInUseOnly: return "location.circle"
        case .lowPowerMode: return "bolt.slash.fill"
        case .batteryUnder15: return "battery.25"
        case .deviceUnplugged: return "battery.50"
        }
    }
}
