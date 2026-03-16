import SwiftUI

enum TabItem: String, CaseIterable {
    case map
    case feed
    case social
    case profile

    var title: String {
        switch self {
        case .map: return "Map"
        case .feed: return "Feed"
        case .social: return "Social"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .map: return "map"
        case .feed: return "rectangle.stack"
        case .social: return "person.2"
        case .profile: return "person"
        }
    }

    var route: Route {
        switch self {
        case .map: return .map
        case .feed: return .feed
        case .social: return .social
        case .profile: return .profile
        }
    }
}
