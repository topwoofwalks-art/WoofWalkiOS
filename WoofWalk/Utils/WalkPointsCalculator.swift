import Foundation

struct WalkPointsCalculator {
    static let baseWalkPoints = 10
    static let perKmPoints = 5
    static let streakBonusMultiplier = 0.1 // 10% per streak day, max 100%
    static let maxStreakMultiplier = 2.0
    static let charityPointsPercent = 0.25

    struct PointsBreakdown {
        let basePoints: Int
        let distancePoints: Int
        let streakBonus: Int
        let charityPoints: Int
        let totalPoints: Int
        let totalWithCharity: Int
    }

    static func calculatePoints(distanceKm: Double, durationSec: Int, streakDays: Int, charityEnabled: Bool) -> PointsBreakdown {
        let base = baseWalkPoints
        let distance = Int(distanceKm * Double(perKmPoints))

        let streakMultiplier = min(1.0 + Double(streakDays) * streakBonusMultiplier, maxStreakMultiplier)
        let subtotal = base + distance
        let streakBonus = Int(Double(subtotal) * (streakMultiplier - 1.0))
        let total = subtotal + streakBonus

        let charity = charityEnabled ? Int(Double(total) * charityPointsPercent) : 0

        return PointsBreakdown(
            basePoints: base,
            distancePoints: distance,
            streakBonus: streakBonus,
            charityPoints: charity,
            totalPoints: total,
            totalWithCharity: total + charity
        )
    }
}
