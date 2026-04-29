import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @EnvironmentObject var settings: WatchSettings

    var body: some View {
        TabView {
            WalkView()
                .environmentObject(sessionManager)
                .environmentObject(settings)

            if settings.compassEnabled && settings.hasMagnetometer {
                CompassView()
                    .environmentObject(sessionManager)
            }

            if settings.messagesEnabled {
                MessagesView()
                    .environmentObject(sessionManager)
            }

            // SOS — always available, never gated by a setting.
            // Wearer-side panic button. Hold-to-send to phone, which
            // writes /sos_alerts and dispatches FCM to emergency
            // contacts via onSosAlertCreate CF.
            SosView()
                .environmentObject(sessionManager)
        }
        .tabViewStyle(.page)
    }
}
