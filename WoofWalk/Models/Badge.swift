#if false
// DISABLED: Duplicate Badge types - real versions defined elsewhere
import Foundation
import SwiftUI

struct Badge: Identifiable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let unlockCriteria: BadgeCriteria
    let rarity: BadgeRarity
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
}

struct BadgeDefinitions {
    static let allBadges: [Badge] = [
        Badge(
            id: BadgeIds.firstWalk,
            name: "First Steps",
            description: "Complete your first walk",
            iconName: "figure.walk",
            unlockCriteria: BadgeCriteria(type: .walksCompleted, targetValue: 1),
            rarity: .common
        ),
        Badge(
            id: BadgeIds.walk5km,
            name: "5K Walker",
            description: "Walk a total of 5 kilometers",
            iconName: "figure.walk.circle",
            unlockCriteria: BadgeCriteria(type: .distanceTotal, targetValue: 5000),
            rarity: .common
        ),
        Badge(
            id: BadgeIds.walk10km,
            name: "10K Champion",
            description: "Walk a total of 10 kilometers",
            iconName: "medal",
            unlockCriteria: BadgeCriteria(type: .distanceTotal, targetValue: 10000),
            rarity: .rare
        ),
        Badge(
            id: BadgeIds.walkMarathon,
            name: "Marathon Walker",
            description: "Walk a total of 42.2 kilometers",
            iconName: "trophy",
            unlockCriteria: BadgeCriteria(type: .distanceTotal, targetValue: 42195),
            rarity: .epic
        ),
        Badge(
            id: BadgeIds.walk100Total,
            name: "Century Club",
            description: "Complete 100 walks",
            iconName: "star.circle.fill",
            unlockCriteria: BadgeCriteria(type: .walksCompleted, targetValue: 100),
            rarity: .epic
        ),
        Badge(
            id: BadgeIds.firstPoi,
            name: "Explorer",
            description: "Create your first point of interest",
            iconName: "mappin.circle",
            unlockCriteria: BadgeCriteria(type: .poisCreated, targetValue: 1),
            rarity: .common
        ),
        Badge(
            id: BadgeIds.poiCreator10,
            name: "Map Maker",
            description: "Create 10 points of interest",
            iconName: "map",
            unlockCriteria: BadgeCriteria(type: .poisCreated, targetValue: 10),
            rarity: .rare
        ),
        Badge(
            id: BadgeIds.poiCreator50,
            name: "Cartographer",
            description: "Create 50 points of interest",
            iconName: "map.fill",
            unlockCriteria: BadgeCriteria(type: .poisCreated, targetValue: 50),
            rarity: .legendary
        ),
        Badge(
            id: BadgeIds.helpfulVoter,
            name: "Community Helper",
            description: "Vote on 25 points of interest",
            iconName: "hand.thumbsup",
            unlockCriteria: BadgeCriteria(type: .votesGiven, targetValue: 25),
            rarity: .rare
        ),
        Badge(
            id: BadgeIds.earlyAdopter,
            name: "Early Adopter",
            description: "Join WoofWalk in the first month",
            iconName: "flame",
            unlockCriteria: BadgeCriteria(type: .special, targetValue: 1),
            rarity: .legendary
        ),
        Badge(
            id: BadgeIds.communityHero,
            name: "Community Hero",
            description: "Make 100 contributions to the community",
            iconName: "heart.circle.fill",
            unlockCriteria: BadgeCriteria(type: .special, targetValue: 100),
            rarity: .legendary
        )
    ]

    static func getBadge(id: String) -> Badge? {
        allBadges.first { $0.id == id }
    }
}
#endif
