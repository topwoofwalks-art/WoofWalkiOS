import Foundation

struct WalkStreak: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastWalkDate: String // YYYY-MM-DD
    var streakStartDate: String // YYYY-MM-DD
    var freezesAvailable: Int
    var freezeUsedDate: String? // YYYY-MM-DD

    static let milestoneDays = [7, 14, 30, 60, 90, 180, 365]
    static let maxFreezes = 3
    static let freezeEarnInterval = 7

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastWalkDate: String = "", streakStartDate: String = "", freezesAvailable: Int = 0, freezeUsedDate: String? = nil) {
        self.currentStreak = currentStreak; self.longestStreak = longestStreak; self.lastWalkDate = lastWalkDate; self.streakStartDate = streakStartDate; self.freezesAvailable = freezesAvailable; self.freezeUsedDate = freezeUsedDate
    }

    var isAtMilestone: Bool {
        WalkStreak.milestoneDays.contains(currentStreak)
    }

    var nextMilestone: Int? {
        WalkStreak.milestoneDays.first { $0 > currentStreak }
    }

    var daysToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next - currentStreak
    }
}
