import SwiftUI
import Firebase

@main
struct WoofWalkApp: App {
    @StateObject private var screenshotAutomation = ScreenshotAutomation.shared

    init() {
        // Only configure Firebase if GoogleService-Info.plist exists
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        } else {
            print("[WoofWalk] GoogleService-Info.plist not found - Firebase disabled")
        }

        NotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    await NotificationService.shared.requestPermission()
                }
                .task {
                    await screenshotAutomation.runAutomation()
                }
        }
    }
}
