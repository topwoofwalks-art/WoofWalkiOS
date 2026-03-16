import Foundation

struct StreakCalculator {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    static func yesterdayString() -> String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return dateFormatter.string(from: yesterday)
    }

    static func updateStreak(_ streak: WalkStreak, walkDate: Date = Date()) -> WalkStreak {
        var updated = streak
        let walkDateStr = dateFormatter.string(from: walkDate)
        let today = todayString()
        let yesterday = yesterdayString()

        // Already walked today
        if updated.lastWalkDate == today { return updated }

        if updated.lastWalkDate == yesterday || updated.currentStreak == 0 {
            // Continue or start streak
            updated.currentStreak += 1
            if updated.currentStreak == 1 {
                updated.streakStartDate = walkDateStr
            }
        } else if updated.freezesAvailable > 0 && updated.freezeUsedDate != yesterday {
            // Use freeze
            updated.freezesAvailable -= 1
            updated.freezeUsedDate = yesterday
            updated.currentStreak += 1
        } else {
            // Streak broken - restart
            updated.currentStreak = 1
            updated.streakStartDate = walkDateStr
        }

        updated.lastWalkDate = walkDateStr
        updated.longestStreak = max(updated.longestStreak, updated.currentStreak)

        // Earn freeze every N days
        if updated.currentStreak > 0 && updated.currentStreak % WalkStreak.freezeEarnInterval == 0 && updated.freezesAvailable < WalkStreak.maxFreezes {
            updated.freezesAvailable += 1
        }

        return updated
    }

    static func isStreakActive(_ streak: WalkStreak) -> Bool {
        let today = todayString()
        let yesterday = yesterdayString()
        return streak.lastWalkDate == today || streak.lastWalkDate == yesterday
    }
}
