import SwiftUI
import Combine

@MainActor
class NavigationViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var selectedTab: TabItem = .map
    @Published var showSheet: AppRoute?
    @Published var activeAlert: AppAlert?

    func navigate(to route: AppRoute) {
        navigationPath.append(route)
    }

    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func navigateToRoot() {
        navigationPath = NavigationPath()
    }

    func popTo(route: AppRoute) {
        // NavigationPath doesn't expose its elements directly;
        // pop back to root as a safe fallback.
        navigationPath = NavigationPath()
    }

    func presentSheet(_ route: AppRoute) {
        showSheet = route
    }

    func dismissSheet() {
        showSheet = nil
    }

    func showAlert(_ alert: AppAlert) {
        activeAlert = alert
    }

    func dismissAlert() {
        activeAlert = nil
    }

    func selectTab(_ tab: TabItem) {
        if selectedTab == tab {
            navigationPath = NavigationPath()
        } else {
            selectedTab = tab
        }
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme == "woofwalk" else { return }

        let path = url.host ?? ""
        let components = url.pathComponents.filter { $0 != "/" }

        switch path {
        case "walk":
            if let walkId = components.first {
                navigate(to: .walkDetail(walkId: walkId))
            }
        case "dog":
            if let dogId = components.first {
                selectTab(.profile)
                navigate(to: .dogStats(dogId: dogId))
            }
        case "poi":
            if let poiId = components.first {
                selectTab(.map)
                navigate(to: .walkDetail(walkId: poiId))
            }
        case "chat":
            if let chatId = components.first {
                selectTab(.social)
                navigate(to: .chatDetail(chatId: chatId))
            }
        default:
            break
        }
    }
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: AlertButton?
    let secondaryButton: AlertButton?

    struct AlertButton {
        let title: String
        let action: () -> Void
    }
}
