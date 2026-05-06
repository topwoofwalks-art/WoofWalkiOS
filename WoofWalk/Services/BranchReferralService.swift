import Foundation
import UIKit
import FirebaseAuth
import FirebaseFunctions

#if canImport(BranchSDK)
import BranchSDK
#endif

// TODO(launch): Branch live + test keys come from the Branch dashboard.
// They're plumbed via Info.plist (`BranchKey` / `BranchKeyTest`) so the
// ops team can rotate them without a code push. If either key is the
// `BRANCH_KEY_NEEDED` sentinel string the service short-circuits — the
// app still launches, deeplinks still route through the existing
// `woofwalk://` `onOpenURL` path, and signup attribution simply no-ops.

/// Self-hosted referral attribution + Branch.io deferred deep-link
/// bridge. Mirrors `app/src/main/java/com/woofwalk/util/ReferralAttribution.kt`
/// on Android — both sides eventually call the same `attributeInstall`
/// callable Cloud Function, which writes `users/{uid}.referredBy`,
/// creates the `referrals/{id}` doc, and bumps the inviter's
/// `successfulReferrals` counter.
///
/// Two-stage flow (parallels Android's Play Install Referrer + fingerprint):
///
///   1. FAST PATH — Branch.io's deferred deep-link callback delivers
///      the referral payload from a `woofwalk.app/invite?ref=CODE` link
///      that was clicked before install. We extract the `ww_ref` value
///      and pass it to `attributeInstall` as `installReferrer`.
///
///   2. SLOW PATH — if Branch returns no referring link (sideload, dev
///      build with no key, link expired) we fall back to fingerprint
///      matching. We call `attributeInstall` without an
///      `installReferrer`; the CF then matches the caller's
///      hashed IP+UA against `/referral_clicks` for the previous 24h.
///
/// Idempotent: stores `referral_attribution_attempted` in `UserDefaults`
/// so it only runs once per install. The CF re-checks
/// `users/{uid}.referredBy` and no-ops if already attributed — defence
/// in depth.
///
/// Not `@MainActor` — the Branch SDK is thread-safe internally and we
/// want `configure()` callable synchronously from `WoofWalkApp.init()`,
/// matching how `NotificationService.shared.configure()` and
/// `PhoneWatchSessionManager.shared.activate()` are invoked. State
/// reads/writes (the `didStart` flag, `UserDefaults`) are all
/// effectively serialised through main-thread callers in practice.
final class BranchReferralService: NSObject, @unchecked Sendable {
    static let shared = BranchReferralService()

    private enum Defaults {
        static let attempted = "referral_attribution_attempted"
        static let pendingCode = "referral_attribution_pending_code"
        static let pendingDeepLink = "referral_attribution_deep_link"
    }

    private let userDefaults: UserDefaults = .standard
    private var didStart = false

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Initialise the Branch SDK at app launch. Safe to call from
    /// `WoofWalkApp.init()`. Idempotent — repeat calls are ignored.
    /// If Branch keys aren't configured (dev builds, simulator without
    /// secrets) this still succeeds; the service simply runs in
    /// fingerprint-only mode.
    func configure() {
        guard !didStart else { return }
        didStart = true

        #if canImport(BranchSDK)
        guard let liveKey = Bundle.main.object(forInfoDictionaryKey: "BranchKey") as? String,
              !liveKey.isEmpty,
              liveKey != "BRANCH_KEY_NEEDED" else {
            print("[BranchReferralService] BranchKey missing or placeholder — skipping init. " +
                  "Fingerprint-only attribution will still work.")
            return
        }

        let branch = Branch.getInstance()

        // Test key (optional). When present, debug builds use the test
        // environment automatically — matches the Branch dashboard's
        // dev/prod split.
        #if DEBUG
        if let testKey = Bundle.main.object(forInfoDictionaryKey: "BranchKeyTest") as? String,
           !testKey.isEmpty,
           testKey != "BRANCH_KEY_NEEDED" {
            branch.setDebug()
        }
        #endif
        #else
        print("[BranchReferralService] BranchSDK not linked — skipping init.")
        #endif
    }

    /// Hand off the launch-options dict from `application(_:didFinishLaunchingWithOptions:)`.
    /// Branch needs this to read the deferred deep-link payload from
    /// the install Postback. Called by `BranchAppDelegate`.
    func initSession(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if canImport(BranchSDK)
        Branch.getInstance().initSession(launchOptions: launchOptions) { [weak self] params, error in
            // params is `[AnyHashable: Any]?` containing the link's
            // custom data, plus standard `+clicked_branch_link` /
            // `+is_first_session` flags.
            self?.handleBranchParams(params, error: error)
        }
        #endif
    }

    // MARK: - URL handlers

    /// Universal-link callback — wire from
    /// `application(_:continue:restorationHandler:)`. Returns true if
    /// Branch consumed the activity (it usually does for `.app.link`
    /// domains); the caller should NOT route the URL through
    /// `WoofWalkApp.handleDeeplink` in that case.
    @discardableResult
    func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        #if canImport(BranchSDK)
        return Branch.getInstance().continue(userActivity)
        #else
        return false
        #endif
    }

    /// Custom-scheme URL callback — wire from
    /// `application(_:open:options:)`. Branch returns true when the URL
    /// was a Branch link; otherwise the caller should fall through to
    /// the existing `woofwalk://` deeplink routing in `WoofWalkApp`.
    @discardableResult
    func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        #if canImport(BranchSDK)
        return Branch.getInstance().application(UIApplication.shared, open: url, options: options)
        #else
        return false
        #endif
    }

    // MARK: - Branch params parsing

    private func handleBranchParams(_ params: [AnyHashable: Any]?, error: Error?) {
        if let error = error {
            print("[BranchReferralService] initSession error: \(error.localizedDescription)")
            return
        }
        guard let params = params else { return }

        // First-session flag — Branch only emits the deferred deep-link
        // params on the FIRST app open after install. After that
        // `+clicked_branch_link` may still be true for subsequent
        // organic Branch link clicks, but we treat the first-session
        // payload as the install-referrer source.
        let clicked = (params["+clicked_branch_link"] as? Bool) ?? false
        if !clicked {
            return
        }

        // Look for `ww_ref` first (matches the Android Play Install
        // Referrer query string format the portal generates), then fall
        // back to `ref` / `referrer_code` for forward-compat with any
        // future Branch dashboard custom links.
        let code: String? = (params["ww_ref"] as? String)
            ?? (params["ref"] as? String)
            ?? (params["referrer_code"] as? String)
        let deepLink: String? = (params["dl"] as? String)
            ?? (params["deepLink"] as? String)
            ?? (params["$deeplink_path"] as? String)

        if let code = code, !code.isEmpty {
            print("[BranchReferralService] captured referral code from Branch: \(code)")
            userDefaults.set(code, forKey: Defaults.pendingCode)
            if let dl = deepLink, !dl.isEmpty {
                userDefaults.set(dl, forKey: Defaults.pendingDeepLink)
            }
        }
    }

    // MARK: - Attribution

    /// Idempotent — call from the post-sign-in boot path (i.e. when
    /// `authState` flips to `.authenticated`). Safe to call repeatedly;
    /// returns immediately on subsequent calls or if no user is
    /// signed-in.
    func attributeIfNeeded() async {
        guard Auth.auth().currentUser != nil else { return }
        if userDefaults.bool(forKey: Defaults.attempted) { return }

        // Mark attempted BEFORE calling so we don't loop on transient
        // network errors. The server is idempotent — a retry on
        // reinstall after data clear re-attempts attribution; that's
        // intentional, the user might have clicked a fresh invite.
        userDefaults.set(true, forKey: Defaults.attempted)

        let pendingCode = userDefaults.string(forKey: Defaults.pendingCode)
        let pendingDeepLink = userDefaults.string(forKey: Defaults.pendingDeepLink)

        // Build the `installReferrer` string in the exact format the
        // CF expects (Play Install Referrer query-string format —
        // `ww_ref=CODE&dl=DEEPLINK`). The CF parses with
        // URLSearchParams so any URL-encodable string works.
        var installReferrer: String? = nil
        if let code = pendingCode, !code.isEmpty {
            var parts = ["ww_ref=\(code)"]
            if let dl = pendingDeepLink, !dl.isEmpty,
               let escaped = dl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                parts.append("dl=\(escaped)")
            }
            installReferrer = parts.joined(separator: "&")
        }

        do {
            let functions = Functions.functions(region: "europe-west2")
            var payload: [String: Any] = [
                "fallbackUserAgent": userAgent()
            ]
            if let installReferrer = installReferrer {
                payload["installReferrer"] = installReferrer
            }
            let result = try await functions
                .httpsCallable("attributeInstall")
                .call(payload)
            let data = result.data as? [String: Any]
            let attributed = (data?["attributed"] as? Bool) ?? false
            if attributed {
                let method = (data?["method"] as? String) ?? "unknown"
                let code = (data?["code"] as? String) ?? "?"
                print("[BranchReferralService] attributed via \(method) code=\(code)")
                if let dl = data?["deepLink"] as? String, !dl.isEmpty {
                    userDefaults.set(dl, forKey: Defaults.pendingDeepLink)
                }
            } else {
                let reason = (data?["reason"] as? String) ?? "no_click"
                print("[BranchReferralService] no match (\(reason))")
            }
        } catch {
            print("[BranchReferralService] CF call failed; will not retry: \(error.localizedDescription)")
        }

        // Clear the pending code regardless — the CF either consumed
        // it or didn't find a match. Either way it's stale now.
        userDefaults.removeObject(forKey: Defaults.pendingCode)
    }

    /// Returns any pending deferred deep-link target captured by a
    /// referral click. Single-shot — clears the value once read so a
    /// duplicate boot doesn't bounce the user to the same screen
    /// twice. Mirrors Android's `consumePendingDeepLink()`.
    func consumePendingDeepLink() -> String? {
        guard let v = userDefaults.string(forKey: Defaults.pendingDeepLink),
              !v.isEmpty else { return nil }
        userDefaults.removeObject(forKey: Defaults.pendingDeepLink)
        return v
    }

    // MARK: - Helpers

    private func userAgent() -> String {
        // Cheap stable fingerprint matching server-side hash. Format
        // mirrors what the portal /invite landing reports — keep it
        // aligned with Android's `WoofWalkApp/Android $sdk; $model` so
        // the fingerprint hash bucket is meaningful across platforms.
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = device.model.replacingOccurrences(of: "  ", with: " ")
        return "WoofWalkApp/iOS \(systemVersion); \(model)"
    }
}
