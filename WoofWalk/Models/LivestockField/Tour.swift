#if false
// DISABLED: Duplicate Tour/TourStep/TourAction types - real versions in Tour/TourModels.swift
import Foundation

struct Tour: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let steps: [TourStep]
    let targetScreen: TourTarget
    let priority: Int
    var completedAt: Date?

    var isCompleted: Bool {
        completedAt != nil
    }

    var progress: Double {
        guard !steps.isEmpty else { return 0.0 }
        let completed = steps.filter { $0.isCompleted }.count
        return Double(completed) / Double(steps.count)
    }
}

struct TourStep: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let message: String
    let targetElement: String?
    let action: TourAction?
    let order: Int
    var isCompleted: Bool

    var icon: String {
        action?.icon ?? "info.circle"
    }
}

enum TourAction: String, Codable {
    case tap = "tap"
    case swipe = "swipe"
    case longPress = "longPress"
    case doubleTap = "doubleTap"

    var icon: String {
        switch self {
        case .tap: return "hand.tap"
        case .swipe: return "hand.draw"
        case .longPress: return "hand.point.up.left"
        case .doubleTap: return "hand.tap.fill"
        }
    }

    var displayName: String {
        switch self {
        case .tap: return "Tap"
        case .swipe: return "Swipe"
        case .longPress: return "Long Press"
        case .doubleTap: return "Double Tap"
        }
    }
}

enum TourTarget: String, Codable {
    case map = "map"
    case walkTracking = "walkTracking"
    case poi = "poi"
    case profile = "profile"
    case settings = "settings"
    case livestockFields = "livestockFields"
    case walkingPaths = "walkingPaths"

    var displayName: String {
        switch self {
        case .map: return "Map"
        case .walkTracking: return "Walk Tracking"
        case .poi: return "Points of Interest"
        case .profile: return "Profile"
        case .settings: return "Settings"
        case .livestockFields: return "Livestock Fields"
        case .walkingPaths: return "Walking Paths"
        }
    }
}

struct TourCompletion: Codable, Equatable {
    let tourId: String
    let userId: String
    let completedAt: Date
    let stepsCompleted: Int
    let totalSteps: Int
}
#endif
