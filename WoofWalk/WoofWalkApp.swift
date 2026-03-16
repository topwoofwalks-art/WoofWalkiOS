import SwiftUI
import Firebase

@main
struct WoofWalkApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
