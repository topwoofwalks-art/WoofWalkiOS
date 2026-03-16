import SwiftUI

@MainActor
class AppNavigator: ObservableObject {
    static let shared = AppNavigator()

    @Published var path = NavigationPath()
    @Published var selectedTab: AppTab = .map

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func switchTab(_ tab: AppTab) {
        selectedTab = tab
    }
}

enum AppTab: String, CaseIterable {
    case map = "Map"
    case social = "Social"
    case discover = "Discover"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .map: return "map.fill"
        case .social: return "person.3.fill"
        case .discover: return "magnifyingglass"
        case .profile: return "person.circle.fill"
        }
    }
}
