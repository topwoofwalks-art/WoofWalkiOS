import SwiftUI
import FirebaseAuth

@MainActor
class ScreenshotAutomation: ObservableObject {
    static let shared = ScreenshotAutomation()

    var isScreenshotMode: Bool {
        CommandLine.arguments.contains("-screenshot-mode")
    }

    func runAutomation() async {
        guard isScreenshotMode else { return }

        print("[ScreenshotAutomation] Starting automated screenshot sequence")

        // Step 1: Try sign-in (but continue even if it fails)
        let email = ProcessInfo.processInfo.environment["TEST_EMAIL"]
            ?? UserDefaults.standard.string(forKey: "TEST_EMAIL") ?? ""
        let password = ProcessInfo.processInfo.environment["TEST_PASSWORD"]
            ?? UserDefaults.standard.string(forKey: "TEST_PASSWORD") ?? ""

        if !email.isEmpty && !password.isEmpty {
            print("[ScreenshotAutomation] Signing in as \(email)...")
            do {
                try await Auth.auth().signIn(withEmail: email, password: password)
                print("[ScreenshotAutomation] Sign-in successful")
            } catch {
                print("[ScreenshotAutomation] Sign-in failed: \(error.localizedDescription) - continuing without auth")
            }
        } else {
            print("[ScreenshotAutomation] No credentials - continuing without sign-in")
        }

        // Step 2: Stay on map for first capture (CI captures at ~10s)
        print("[ScreenshotAutomation] Holding MAP tab for capture...")
        AppNavigator.shared.selectedTab = .map
        try? await Task.sleep(nanoseconds: 12_000_000_000) // Hold 12s for CI to capture map

        // Step 3: Switch to social (CI captures at ~22s)
        print("[ScreenshotAutomation] SWITCHING to: social")
        AppNavigator.shared.selectedTab = .social
        try? await Task.sleep(nanoseconds: 12_000_000_000) // Hold 12s

        // Step 4: Switch to discover (CI captures at ~34s)
        print("[ScreenshotAutomation] SWITCHING to: discover")
        AppNavigator.shared.selectedTab = .discover
        try? await Task.sleep(nanoseconds: 12_000_000_000) // Hold 12s

        // Step 5: Switch to profile (CI captures at ~46s)
        print("[ScreenshotAutomation] SWITCHING to: profile")
        AppNavigator.shared.selectedTab = .profile
        try? await Task.sleep(nanoseconds: 12_000_000_000) // Hold 12s

        // Step 6: Back to map for final shot (CI captures at ~54s)
        print("[ScreenshotAutomation] SWITCHING back to: map")
        AppNavigator.shared.selectedTab = .map
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        print("[ScreenshotAutomation] COMPLETE")
    }
}
