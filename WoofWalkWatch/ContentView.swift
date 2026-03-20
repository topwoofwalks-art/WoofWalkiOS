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
        }
        .tabViewStyle(.page)
    }
}
