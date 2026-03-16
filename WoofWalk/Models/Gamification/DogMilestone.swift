import Foundation

enum MilestoneType: String, Codable, CaseIterable {
    case walkCount = "WALK_COUNT"
    case distance = "DISTANCE"
    case streak = "STREAK"
    case timeTogether = "TIME_TOGETHER"
    case funDistance = "FUN_DISTANCE"
}

struct DogMilestone: Identifiable, Codable {
    let id: String
    let type: MilestoneType
    let title: String
    let subtitle: String
    let pawPointsBonus: Int
    let threshold: Int64

    init(id: String = UUID().uuidString, type: MilestoneType, title: String, subtitle: String, pawPointsBonus: Int, threshold: Int64) {
        self.id = id; self.type = type; self.title = title; self.subtitle = subtitle; self.pawPointsBonus = pawPointsBonus; self.threshold = threshold
    }
}

struct DogWalkStats: Codable {
    var totalWalks: Int
    var totalDistanceMeters: Int64
    var currentStreak: Int
    var longestStreak: Int
    var firstWalkDate: Int64?
    var achievedMilestones: [String]

    init(totalWalks: Int = 0, totalDistanceMeters: Int64 = 0, currentStreak: Int = 0, longestStreak: Int = 0, firstWalkDate: Int64? = nil, achievedMilestones: [String] = []) {
        self.totalWalks = totalWalks; self.totalDistanceMeters = totalDistanceMeters; self.currentStreak = currentStreak; self.longestStreak = longestStreak; self.firstWalkDate = firstWalkDate; self.achievedMilestones = achievedMilestones
    }
}

struct MilestoneCheckResult {
    let dogId: String
    let dogName: String
    let dogPhotoUrl: String?
    let newMilestones: [DogMilestone]
    let updatedStats: DogWalkStats
}
