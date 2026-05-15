import Foundation
import FirebaseAppCheck
import FirebaseCore

/// Production App Check provider factory. Selects the strongest available
/// attestation provider for the host OS:
///
///   - iOS 14+ → `AppAttestProvider` (Apple's hardware-backed key
///     attestation. Equivalent to Android's Play Integrity).
///   - iOS 11-13 → `DeviceCheckProvider` (the older per-device token
///     scheme. Still trusted by App Check enforcement, just lower
///     assurance — pre-iOS-14 is a tiny installed-base slice but we
///     need a non-nil provider to keep the backend from rejecting the
///     call entirely).
///
/// DEBUG builds use `AppCheckDebugProviderFactory` directly in
/// `WoofWalkApp.init()` so simulator + sideloaded dev builds aren't
/// rejected by enforcement — see WoofWalkApp.swift.
///
/// Mirrors Android `WoofWalkApplication.kt` which calls
/// `FirebaseAppCheck.getInstance().installAppCheckProviderFactory(
///   PlayIntegrityAppCheckProviderFactory.getInstance())`.
final class WoofWalkAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
    }
}
