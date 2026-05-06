import Foundation
import GoogleMobileAds
import UIKit
import AppTrackingTransparency

/// Loads + presents rewarded interstitial ads to gate the charity-
/// points award. Mirrors Android `app/src/main/java/com/woofwalk/util/
/// CharityAdManager.kt` exactly — same lifecycle (preload → show →
/// reward callback flips a flag → walk-end repo reads flag → award).
///
/// Ad-unit IDs:
///   - DEBUG: Google's universal test rewarded-interstitial ID
///     (ca-app-pub-3940256099942544/6978759866)
///   - RELEASE: WoofWalk's iOS rewarded-interstitial unit, provisioned
///     in AdMob console. Until that's set up, the test ID is used in
///     both — production builds will serve test ads, which is safe
///     (no monetisation) but the user still gets the gate UX.
///
/// Singleton because there's only ever one in-flight rewarded ad and
/// because the @ApplicationContext-equivalent on iOS is "shared
/// instance" — same lifecycle scope.
@MainActor
final class CharityAdManager: NSObject {
    static let shared = CharityAdManager()

    // DEBUG uses Google's universal test rewarded-interstitial unit
    // (no monetisation, infinite fillrate). RELEASE uses WoofWalk's
    // own iOS rewarded-interstitial unit, provisioned 2026-05-06 in
    // the same AdMob account as Android (publisher 6114201892028196).
    // Mirrors the same DEBUG-vs-RELEASE split Android uses in
    // util/CharityAdManager.kt:16-19.
    private static let testAdUnitID = "ca-app-pub-3940256099942544/6978759866"
    private static let prodAdUnitID = "ca-app-pub-6114201892028196/7471026019"

    private var adUnitID: String {
        #if DEBUG
        return Self.testAdUnitID
        #else
        return Self.prodAdUnitID
        #endif
    }

    private var rewardedInterstitialAd: RewardedInterstitialAd?
    private var isLoading = false

    /// One-shot ATT prompt — iOS 14.5+ requires explicit user
    /// authorization before the SDK can request IDFA. Even on `.denied`
    /// the SDK still serves ads (non-personalised) so the gate works.
    /// Idempotent — once authorized/denied/restricted the system
    /// remembers the answer and the prompt never re-shows.
    func requestTrackingAuthorizationIfNeeded() async {
        if #available(iOS 14.5, *) {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
    }

    /// Preload a rewarded interstitial so it's ready when the user taps
    /// "Watch Ad & Walk". Idempotent — a no-op if an ad is already
    /// loaded or in-flight. Safe to call repeatedly (e.g. from
    /// LaunchedEffect / .task on dog-selection screen).
    func preloadAd() {
        if isLoading || rewardedInterstitialAd != nil {
            print("[CharityAdManager] preload: already loaded or loading")
            return
        }
        isLoading = true

        let request = Request()
        RewardedInterstitialAd.load(
            with: adUnitID,
            request: request
        ) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                print("[CharityAdManager] preload failed: \(error.localizedDescription)")
                self.rewardedInterstitialAd = nil
                return
            }
            self.rewardedInterstitialAd = ad
            ad?.fullScreenContentDelegate = self
            print("[CharityAdManager] preloaded rewarded interstitial")
        }
    }

    var isAdReady: Bool { rewardedInterstitialAd != nil }

    /// Present the loaded rewarded interstitial.
    /// - `onRewardEarned` fires when the user has watched enough of the
    ///   ad to earn the reward (Google's threshold; usually ~5-15 s in).
    /// - `onAdDismissed` fires when the ad's full-screen view closes,
    ///   regardless of whether reward was earned. Use this to start the
    ///   walk regardless.
    /// - `onAdFailed` fires if no ad is loaded or presentation fails;
    ///   start the walk anyway, no points awarded.
    func showAd(
        from rootViewController: UIViewController,
        onRewardEarned: @escaping () -> Void,
        onAdDismissed: @escaping () -> Void,
        onAdFailed: @escaping () -> Void
    ) {
        guard let ad = rewardedInterstitialAd else {
            print("[CharityAdManager] showAd: no ad ready")
            onAdFailed()
            return
        }

        // Stash callbacks on the delegate so the dispatch from
        // GADFullScreenContentDelegate methods picks them up.
        self.pendingDismissed = onAdDismissed
        self.pendingFailed = onAdFailed

        ad.present(from: rootViewController) {
            let reward = ad.adReward
            print("[CharityAdManager] reward earned: \(reward.amount) \(reward.type)")
            onRewardEarned()
        }
    }

    func clear() {
        rewardedInterstitialAd = nil
        isLoading = false
        pendingDismissed = nil
        pendingFailed = nil
    }

    // MARK: - Delegate state plumbing

    private var pendingDismissed: (() -> Void)?
    private var pendingFailed: (() -> Void)?
}

extension CharityAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("[CharityAdManager] ad dismissed")
        rewardedInterstitialAd = nil
        let dismissed = pendingDismissed
        pendingDismissed = nil
        pendingFailed = nil
        dismissed?()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("[CharityAdManager] ad failed to present: \(error.localizedDescription)")
        rewardedInterstitialAd = nil
        let failed = pendingFailed
        pendingDismissed = nil
        pendingFailed = nil
        failed?()
    }
}
