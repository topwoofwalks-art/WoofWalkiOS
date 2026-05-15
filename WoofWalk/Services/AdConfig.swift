import Foundation

/// Centralised ad unit IDs for banner + native feed ads on iOS.
///
/// Mirrors `app/src/main/java/com/woofwalk/ui/components/AdBanner.kt`'s `AdConfig` object
/// — same test/prod split, same naming, same selection logic. The only difference is which
/// universal test IDs Google publishes per platform (the iOS variants are used here; the
/// Android file uses the Android variants).
///
/// DEBUG  → Google's universal test ad units (no monetisation, infinite fillrate).
/// RELEASE → WoofWalk's own iOS ad units, provisioned 2026-05-08 in the AdMob console
///           under publisher 6114201892028196 (same account as Android).
///
/// The rewarded-interstitial unit (used by `CharityAdManager`) is intentionally NOT in
/// here — it's defined inline in `CharityAdManager.swift` to keep that manager
/// self-contained, mirroring `util/CharityAdManager.kt` on Android.
enum AdConfig {
    // Test IDs — Google's universal test ad units for iOS.
    // Reference: https://developers.google.com/admob/ios/test-ads
    static let bannerAdUnitIDTest = "ca-app-pub-3940256099942544/2934735716"
    static let nativeFeedIDTest   = "ca-app-pub-3940256099942544/3986624511"

    // Production IDs — Woofwalk iOS ad units provisioned in AdMob.
    static let bannerAdUnitIDProd = "ca-app-pub-6114201892028196/1358103299"
    static let nativeFeedIDProd   = "ca-app-pub-6114201892028196/9627475553"

    static var bannerAdUnitID: String {
        #if DEBUG
        return bannerAdUnitIDTest
        #else
        return bannerAdUnitIDProd
        #endif
    }

    static var nativeFeedID: String {
        #if DEBUG
        return nativeFeedIDTest
        #else
        return nativeFeedIDProd
        #endif
    }
}
