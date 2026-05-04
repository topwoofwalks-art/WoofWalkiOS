import SwiftUI

enum ClientTab: String, CaseIterable {
    case home = "Home"
    case bookings = "Bookings"
    case messages = "Messages"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .bookings: return "calendar.badge.clock"
        case .messages: return "message.fill"
        case .profile: return "person.fill"
        }
    }
}

struct ClientTabView: View {
    @State private var selectedTab: ClientTab = .home

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ClientHomeScreen()
                        .navigationDestination(for: AppRoute.self) { route in
                            RouteDestination(route: route)
                        }
                }
                .tabItem {
                    Label(ClientTab.home.rawValue, systemImage: ClientTab.home.icon)
                }
                .tag(ClientTab.home)

                NavigationStack {
                    ClientBookingsScreen()
                }
                .tabItem {
                    Label(ClientTab.bookings.rawValue, systemImage: ClientTab.bookings.icon)
                }
                .tag(ClientTab.bookings)

                NavigationStack {
                    ClientMessagesScreen()
                }
                .tabItem {
                    Label(ClientTab.messages.rawValue, systemImage: ClientTab.messages.icon)
                }
                .tag(ClientTab.messages)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label(ClientTab.profile.rawValue, systemImage: ClientTab.profile.icon)
                }
                .tag(ClientTab.profile)
            }

            AdBannerPlaceholder()
        }
        .tint(.turquoise60)
    }
}
