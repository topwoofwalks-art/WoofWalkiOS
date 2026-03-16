import Foundation

struct LevelCalculator {
    static func calculateLevel(pawPoints: Int) -> Int {
        switch pawPoints {
        case ..<100: return 1
        case 100..<300: return 2
        case 300..<600: return 3
        case 600..<1000: return 4
        case 1000..<1500: return 5
        case 1500..<2100: return 6
        case 2100..<2800: return 7
        case 2800..<3600: return 8
        case 3600..<4500: return 9
        case 4500..<5500: return 10
        default: return 10 + (pawPoints - 5500) / 1000
        }
    }

    static func pointsForLevel(_ level: Int) -> Int {
        switch level {
        case 1: return 0
        case 2: return 100
        case 3: return 300
        case 4: return 600
        case 5: return 1000
        case 6: return 1500
        case 7: return 2100
        case 8: return 2800
        case 9: return 3600
        case 10: return 4500
        default: return 5500 + (level - 10) * 1000
        }
    }

    static func progressToNextLevel(pawPoints: Int) -> Double {
        let currentLevel = calculateLevel(pawPoints: pawPoints)
        let currentLevelPoints = pointsForLevel(currentLevel)
        let nextLevelPoints = pointsForLevel(currentLevel + 1)
        let range = nextLevelPoints - currentLevelPoints
        guard range > 0 else { return 1.0 }
        return Double(pawPoints - currentLevelPoints) / Double(range)
    }

    static func pointsToNextLevel(pawPoints: Int) -> Int {
        let currentLevel = calculateLevel(pawPoints: pawPoints)
        let nextLevelPoints = pointsForLevel(currentLevel + 1)
        return max(0, nextLevelPoints - pawPoints)
    }
}
