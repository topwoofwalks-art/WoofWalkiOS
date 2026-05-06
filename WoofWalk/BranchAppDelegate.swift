import UIKit
import SwiftUI

/// Lightweight `UIApplicationDelegate` we mount via
/// `@UIApplicationDelegateAdaptor` in `WoofWalkApp` purely to forward
/// the URL-handling callbacks the Branch SDK needs.
///
/// Why we need this even though `WoofWalkApp` is a pure-SwiftUI App:
///   * Branch reads the deferred deep-link payload during
///     `didFinishLaunchingWithOptions` — `launchOptions` isn't exposed
///     to a SwiftUI App's `init()`.
///   * Universal links arrive via `application(_:continue:)` — SwiftUI
///     surfaces them through `.onContinueUserActivity(...)` but Branch
///     wants the raw `NSUserActivity` object, not just the URL.
///   * Custom-scheme URLs arrive via `application(_:open:options:)` —
///     SwiftUI's `.onOpenURL` strips the options dict, which Branch
///     uses to dedupe re-opens.
///
/// We forward each callback to `BranchReferralService`, which returns
/// `true` when Branch consumed the URL/activity. When Branch returns
/// `false` we let the system fall through to SwiftUI's
/// `.onOpenURL` / `.onContinueUserActivity` handlers, where the
/// existing `woofwalk://` deeplink router in `WoofWalkApp.handleDeeplink`
/// takes over. That keeps the post-walk recap, accept-invite, and
/// future Android-parity hosts working unchanged.
final class BranchAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Hand off to the service — it pulls the deferred deep-link
        // payload from Branch, captures any `ww_ref` referral code into
        // UserDefaults, and primes the post-signup attribution call.
        BranchReferralService.shared.initSession(launchOptions: launchOptions)
        return true
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // Universal links — Branch consumes its own `*.app.link`
        // domains here. Non-Branch URLs (e.g. our Firebase-hosted
        // accept-invite emails) will return false and fall through to
        // SwiftUI's .onContinueUserActivity, which existing iOS code
        // can handle when/if needed.
        return BranchReferralService.shared.handleUserActivity(userActivity)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Custom-scheme URLs (woofwalk://...). Branch returns false for
        // anything that isn't its own — so the woofwalk://walk and
        // woofwalk://accept-invite routes still flow through SwiftUI's
        // `.onOpenURL` handler in WoofWalkApp.body, untouched.
        return BranchReferralService.shared.handleOpenURL(url, options: options)
    }
}
