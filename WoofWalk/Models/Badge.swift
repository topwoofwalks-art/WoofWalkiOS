import Foundation
import SwiftUI

enum BadgeCategory: String, CaseIterable, Identifiable {
    case all
    case walks
    case contributions
    case social
    case special

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .walks: return "Walks"
        case .contributions: return "Contributions"
        case .social: return "Social"
        case .special: return "Special"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .walks: return "figure.walk"
        case .contributions: return "mappin.and.ellipse"
        case .social: return "hand.thumbsup"
        case .special: return "star"
        }
    }
}

struct Badge: Identifiable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let unlockCriteria: BadgeCriteria
    let rarity: BadgeRarity
    let category: BadgeCategory
}

struct BadgeCriteria {
    let type: CriteriaType
    let targetValue: Int
}

enum CriteriaType {
    case walksCompleted
    case distanceTotal
    case poisCreated
    case votesGiven
    case photosUploaded
    case hazardsReported
    case earlyBirdWalks
    case nightOwlWalks
    case uniqueParksVisited
    case timeOfDay
    case special
}

enum BadgeRarity {
    case common
    case rare
    case epic
    case legendary

    var color: Color {
        switch self {
        case .common: return .gray
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .yellow
        }
    }

    var displayName: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
}

/// Canonical badge definitions — IDs must match the server-side
/// `BADGES` constant in `functions/src/gamification/badges.ts`.
struct BadgeDefinitions {
    static let allBadges: [Badge] = [
        Badge(
            id: BadgeIds.firstWalk,
            name: "First Steps",
            description: "Complete your first walk",
            iconName: "figure.walk",
            unlockCriteria: BadgeCriteria(type: .walksCompleted, targetValue: 1),
            rarity: .common,
            category: .walks
        ),
        Badge(
            id: BadgeIds.walk5km,
            name: "5K Walker",
            description: "Walk a total of 5 kilometres",
            iconName: "figure.walk.circle",
            unlockCriteria: BadgeCriteria(type: .distanceTotal, targetValue: 5000),
            rarity: .common,
            category: .walks
        ),
        Badge(
            id: BadgeIds.walk10km,
            name: "10K Champion",
            description: "Walk a total of 10 kilometres",
            iconName: "medal",
            unlockCriteria: BadgeCriteria(type: .distanceTotal, targetValue: 10000),
            rarity: .rare,
            category: .walks
        ),
        Badge(
            id: BadgeIds.walkMarathon,
            name: "Marathon Walker",
            description: "Walk a total of 42.2 kilometres",
            iconName: "trophy",
            unlockCriteria: BadgeCriteria(type: .distanceTotal, targetValue: 42195),
            rarity: .epic,
            category: .walks
        ),
        Badge(
            id: BadgeIds.walk100Total,
            name: "Century Club",
            description: "Complete 100 walks",
            iconName: "star.circle.fill",
            unlockCriteria: BadgeCriteria(type: .walksCompleted, targetValue: 100),
            rarity: .epic,
            category: .walks
        ),
        Badge(
            id: BadgeIds.earlyBird,
            name: "Early Bird",
            description: "Complete 10 walks before 7am",
            iconName: "sunrise",
            unlockCriteria: BadgeCriteria(type: .earlyBirdWalks, targetValue: 10),
            rarity: .rare,
            category: .special
        ),
        Badge(
            id: BadgeIds.nightOwl,
            name: "Night Owl",
            description: "Complete 10 walks after 9pm",
            iconName: "moon.stars",
            unlockCriteria: BadgeCriteria(type: .nightOwlWalks, targetValue: 10),
            rarity: .rare,
            category: .special
        ),
        Badge(
            id: BadgeIds.explorer,
            name: "Explorer",
            description: "Visit 10 unique parks",
            iconName: "mappin.circle",
            unlockCriteria: BadgeCriteria(type: .uniqueParksVisited, targetValue: 10),
            rarity: .rare,
            category: .walks
        ),
        Badge(
            id: BadgeIds.firstPoi,
            name: "Map Maker",
            description: "Create your first point of interest",
            iconName: "mappin.and.ellipse",
            unlockCriteria: BadgeCriteria(type: .poisCreated, targetValue: 1),
            rarity: .common,
            category: .contributions
        ),
        Badge(
            id: BadgeIds.contributor,
            name: "Contributor",
            description: "Create 10 points of interest",
            iconName: "map",
            unlockCriteria: BadgeCriteria(type: .poisCreated, targetValue: 10),
            rarity: .rare,
            category: .contributions
        ),
        Badge(
            id: BadgeIds.poiCreator50,
            name: "Cartographer",
            description: "Create 50 points of interest",
            iconName: "map.fill",
            unlockCriteria: BadgeCriteria(type: .poisCreated, targetValue: 50),
            rarity: .legendary,
            category: .contributions
        ),
        Badge(
            id: BadgeIds.photoMaster,
            name: "Photo Master",
            description: "Upload 50 walk photos",
            iconName: "camera.fill",
            unlockCriteria: BadgeCriteria(type: .photosUploaded, targetValue: 50),
            rarity: .rare,
            category: .contributions
        ),
        Badge(
            id: BadgeIds.guardian,
            name: "Guardian",
            description: "Report 5 hazards to keep dogs safe",
            iconName: "exclamationmark.shield.fill",
            unlockCriteria: BadgeCriteria(type: .hazardsReported, targetValue: 5),
            rarity: .rare,
            category: .contributions
        ),
        Badge(
            id: BadgeIds.social,
            name: "Community Helper",
            description: "Vote on 25 points of interest",
            iconName: "hand.thumbsup",
            unlockCriteria: BadgeCriteria(type: .votesGiven, targetValue: 25),
            rarity: .rare,
            category: .social
        )
    ]

    static func getBadge(id: String) -> Badge? {
        allBadges.first { $0.id == id }
    }
}
