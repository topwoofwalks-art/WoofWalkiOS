import SwiftUI
import WatchConnectivity

@main
struct WoofWalkWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WatchSessionManager.shared)
                .environmentObject(WatchSettings.shared)
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchSessionManager.shared.activate()
        WatchSettings.shared.sendCapabilitiesToPhone()
    }
}
