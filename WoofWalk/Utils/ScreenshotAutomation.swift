import SwiftUI
import FirebaseAuth

/// Handles automated screenshot capture when the app is launched with `-screenshot-mode`.
///
/// Usage from CI:
/// ```
/// xcrun simctl launch --console \
///   -e TEST_EMAIL="user@example.com" \
///   -e TEST_PASSWORD="password" \
///   booted com.woofwalk.app -- -screenshot-mode
/// ```
///
/// The automation signs in, waits for the main screen, then cycles through each tab
/// with a delay, posting `Notification.Name` events that a CI script can listen for
/// via `simctl spawn … log stream` to time `xcrun simctl io screenshot` calls.
@MainActor
class ScreenshotAutomation: ObservableObject {
    static let shared = ScreenshotAutomation()

    /// Whether the app was launched in screenshot mode.
    var isScreenshotMode: Bool {
        CommandLine.arguments.contains("-screenshot-mode")
    }

    // MARK: - Notification Names

    /// Posted when sign-in completes and the main screen is visible.
    static let signInComplete = Notification.Name("screenshot.signInComplete")

    /// Posted when a specific tab is ready for capture.
    /// The `userInfo` dictionary contains `"tab"` with the `AppTab.rawValue`.
    static let tabReady = Notification.Name("screenshot.tabReady")

    /// Posted when the full automation sequence is finished.
    static let automationComplete = Notification.Name("screenshot.automationComplete")

    // MARK: - Configuration

    /// How long to wait on each tab before capturing (seconds).
    private let tabSettleDelay: TimeInterval = 3.0

    /// Extra time to wait after sign-in for data to load.
    private let postSignInDelay: TimeInterval = 5.0

    // MARK: - Run

    /// Entry point called from WoofWalkApp. Does nothing if not in screenshot mode.
    func runAutomation() async {
        guard isScreenshotMode else { return }

        print("[ScreenshotAutomation] Starting automated screenshot sequence")

        // Step 1: Sign in with test credentials (try env vars first, then UserDefaults)
        let email = ProcessInfo.processInfo.environment["TEST_EMAIL"]
            ?? UserDefaults.standard.string(forKey: "TEST_EMAIL") ?? ""
        let password = ProcessInfo.processInfo.environment["TEST_PASSWORD"]
            ?? UserDefaults.standard.string(forKey: "TEST_PASSWORD") ?? ""

        guard !email.isEmpty, !password.isEmpty else {
            print("[ScreenshotAutomation] ERROR: TEST_EMAIL and TEST_PASSWORD not found in env or UserDefaults")
            return
        }

        print("[ScreenshotAutomation] Signing in as \(email)...")

        do {
            try await AuthService.shared.signInWithEmail(email: email, password: password)
            print("[ScreenshotAutomation] Sign-in successful")
        } catch {
            print("[ScreenshotAutomation] ERROR: Sign-in failed: \(error.localizedDescription)")
            return
        }

        // Step 2: Wait for the main screen to settle and data to load
        print("[ScreenshotAutomation] Waiting \(postSignInDelay)s for data to load...")
        try? await Task.sleep(nanoseconds: UInt64(postSignInDelay * 1_000_000_000))

        // Dismiss any pending achievement overlays or onboarding guides
        BadgeAwardingService.shared.pendingAchievements.removeAll()

        NotificationCenter.default.post(name: Self.signInComplete, object: nil)
        print("[ScreenshotAutomation] READY: signInComplete")

        // Step 3: Cycle through each tab
        let tabs: [AppTab] = [.map, .social, .discover, .profile]

        for tab in tabs {
            print("[ScreenshotAutomation] Switching to tab: \(tab.rawValue)")
            AppNavigator.shared.popToRoot()
            AppNavigator.shared.switchTab(tab)

            // Wait for the tab content to render and settle
            try? await Task.sleep(nanoseconds: UInt64(tabSettleDelay * 1_000_000_000))

            NotificationCenter.default.post(
                name: Self.tabReady,
                object: nil,
                userInfo: ["tab": tab.rawValue]
            )
            print("[ScreenshotAutomation] READY: \(tab.rawValue)")
        }

        // Step 4: Done
        NotificationCenter.default.post(name: Self.automationComplete, object: nil)
        print("[ScreenshotAutomation] COMPLETE: All screenshots captured")
    }
}
