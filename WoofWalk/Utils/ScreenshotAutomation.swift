import SwiftUI
import FirebaseAuth

@MainActor
class ScreenshotAutomation: ObservableObject {
    static let shared = ScreenshotAutomation()

    var isScreenshotMode: Bool {
        CommandLine.arguments.contains("-screenshot-mode")
    }

    private let tabSettleDelay: TimeInterval = 5.0

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

        // Step 2: Wait for UI to settle
        print("[ScreenshotAutomation] Waiting for UI to settle...")
        try? await Task.sleep(nanoseconds: 5_000_000_000)

        // Step 3: Cycle through tabs
        let tabs: [AppTab] = [.map, .social, .discover, .profile]

        for tab in tabs {
            print("[ScreenshotAutomation] SWITCHING to: \(tab.rawValue)")
            AppNavigator.shared.selectedTab = tab

            try? await Task.sleep(nanoseconds: UInt64(tabSettleDelay * 1_000_000_000))
            print("[ScreenshotAutomation] READY: \(tab.rawValue)")
        }

        // Step 4: Go back to map for final shot
        AppNavigator.shared.selectedTab = .map
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        print("[ScreenshotAutomation] COMPLETE")
    }
}
