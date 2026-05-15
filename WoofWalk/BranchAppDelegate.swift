import UIKit
import SwiftUI
import FirebaseMessaging

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
        // domains first. If Branch ignores the activity (i.e. it's our
        // own `https://woofwalk.app/...` Universal Link), we forward
        // the `webpageURL` to the same parser as the custom-scheme
        // handler so all 19 Android-parity hosts resolve identically
        // regardless of whether the link arrived as `woofwalk://x/y`
        // or `https://woofwalk.app/x/y`. Mirrors the Android manifest's
        // dual scheme/App-Links intent-filter coverage.
        if BranchReferralService.shared.handleUserActivity(userActivity) {
            return true
        }
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let webURL = userActivity.webpageURL {
            Task { @MainActor in
                WoofWalkApp.handleDeeplink(url: webURL)
            }
            return true
        }
        return false
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

    // MARK: - APNs / FCM registration
    //
    // APNs hands us the device token on the UIApplicationDelegate, not on
    // any SwiftUI surface — so this is the only place we can forward it
    // to FirebaseMessaging. Setting `Messaging.apnsToken` is what triggers
    // the FCM-token callback in `NotificationService` (the
    // `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)`
    // method), which in turn writes the FCM token to
    // `users/{uid}/devices/{installationId}` for server-side targeting —
    // mirroring `WoofWalkMessagingService.onNewToken` on Android.

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        NotificationService.shared.didReceiveRemoteNotificationToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[BranchAppDelegate] APNs registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationService.shared.handleRemoteNotification(userInfo: userInfo)
        completionHandler(.newData)
    }
}
