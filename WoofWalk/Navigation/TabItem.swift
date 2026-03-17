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

    var route: AppRoute {
        switch self {
        case .map: return .map
        case .feed: return .feed
        case .social: return .socialHub
        case .profile: return .profile
        }
    }

    // MARK: - Mode-specific tab configurations

    static var publicTabs: [TabItem] {
        [.map, .feed, .social, .profile]
    }

    static var businessTabs: [BusinessTabItem] {
        BusinessTabItem.allCases
    }

    static var clientTabs: [ClientTabItem] {
        ClientTabItem.allCases
    }
}

// MARK: - Business Tab Configuration

enum BusinessTabItem: String, CaseIterable {
    case dashboard
    case schedule
    case inbox
    case clients
    case earnings

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .schedule: return "Schedule"
        case .inbox: return "Inbox"
        case .clients: return "Clients"
        case .earnings: return "Earnings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .schedule: return "calendar"
        case .inbox: return "tray.fill"
        case .clients: return "person.2.fill"
        case .earnings: return "sterlingsign.circle.fill"
        }
    }

    var route: AppRoute {
        switch self {
        case .dashboard: return .businessDashboard
        case .schedule: return .businessSchedule
        case .inbox: return .businessInbox
        case .clients: return .businessClients
        case .earnings: return .businessEarnings
        }
    }
}

// MARK: - Client Tab Configuration

enum ClientTabItem: String, CaseIterable {
    case dashboard
    case bookings
    case messages
    case invoices

    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .bookings: return "Bookings"
        case .messages: return "Messages"
        case .invoices: return "Invoices"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .bookings: return "calendar.badge.clock"
        case .messages: return "bubble.left.and.bubble.right.fill"
        case .invoices: return "doc.text.fill"
        }
    }

    var route: AppRoute {
        switch self {
        case .dashboard: return .clientDashboard
        case .bookings: return .clientBookings
        case .messages: return .clientMessages
        case .invoices: return .clientInvoices
        }
    }
}
