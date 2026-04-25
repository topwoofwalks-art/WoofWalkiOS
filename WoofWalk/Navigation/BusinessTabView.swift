import SwiftUI

enum BusinessTab: String, CaseIterable {
    case home = "Home"
    case schedule = "Schedule"
    case clients = "Clients"
    case inbox = "Inbox"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .schedule: return "calendar"
        case .clients: return "person.2.fill"
        case .inbox: return "envelope.fill"
        case .profile: return "person.fill"
        }
    }
}

struct BusinessTabView: View {
    @State private var selectedTab: BusinessTab = .home
    @State private var homePath = NavigationPath()
    @StateObject private var businessViewModel = BusinessViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $homePath) {
                    BusinessHomeScreen(viewModel: businessViewModel)
                        .navigationDestination(for: AppRoute.self) { route in
                            RouteDestination(route: route)
                        }
                }
                .tabItem {
                    Label(BusinessTab.home.rawValue, systemImage: BusinessTab.home.icon)
                }
                .tag(BusinessTab.home)

                NavigationStack {
                    BusinessScheduleScreen(viewModel: businessViewModel)
                        .navigationDestination(for: AppRoute.self) { route in
                            RouteDestination(route: route)
                        }
                }
                .tabItem {
                    Label(BusinessTab.schedule.rawValue, systemImage: BusinessTab.schedule.icon)
                }
                .tag(BusinessTab.schedule)

                NavigationStack {
                    BusinessClientsScreen(viewModel: businessViewModel)
                }
                .tabItem {
                    Label(BusinessTab.clients.rawValue, systemImage: BusinessTab.clients.icon)
                }
                .tag(BusinessTab.clients)

                NavigationStack {
                    BusinessInboxScreen()
                }
                .tabItem {
                    Label(BusinessTab.inbox.rawValue, systemImage: BusinessTab.inbox.icon)
                }
                .tag(BusinessTab.inbox)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label(BusinessTab.profile.rawValue, systemImage: BusinessTab.profile.icon)
                }
                .tag(BusinessTab.profile)
            }

            AdBannerPlaceholder()
        }
        .tint(.turquoise60)
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkRouteRequested)) { note in
            // FCM cash-topup deep link → open on the Home stack so the
            // user lands back on the dashboard after the reply view pops.
            if let route = note.userInfo?["route"] as? AppRoute {
                selectedTab = .home
                homePath.append(route)
            }
        }
    }
}
