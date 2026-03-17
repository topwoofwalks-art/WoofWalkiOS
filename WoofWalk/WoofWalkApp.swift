import SwiftUI
import Firebase

@main
struct WoofWalkApp: App {
    @StateObject private var screenshotAutomation = ScreenshotAutomation.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    await screenshotAutomation.runAutomation()
                }
        }
    }
}
