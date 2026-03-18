import Foundation
import FirebaseAuth
import FirebaseFirestore

class MilestoneRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    // MARK: - Walk Count Milestones (matches Android: 1,10,25,50,100,250,500,1000)
    private static let walkCountMilestones: [DogMilestone] = [
        DogMilestone(id: "walks_1", type: .walkCount, title: "First Walk!", subtitle: "The beginning of a beautiful journey", pawPointsBonus: 2, threshold: 1),
        DogMilestone(id: "walks_10", type: .walkCount, title: "10 Walks!", subtitle: "You're building a great habit", pawPointsBonus: 20, threshold: 10),
        DogMilestone(id: "walks_25", type: .walkCount, title: "25 Walks!", subtitle: "A quarter century of walks", pawPointsBonus: 50, threshold: 25),
        DogMilestone(id: "walks_50", type: .walkCount, title: "50 Walks!", subtitle: "Half a hundred adventures", pawPointsBonus: 100, threshold: 50),
        DogMilestone(id: "walks_100", type: .walkCount, title: "100 Walks!", subtitle: "Triple digits - impressive dedication!", pawPointsBonus: 200, threshold: 100),
        DogMilestone(id: "walks_250", type: .walkCount, title: "250 Walks!", subtitle: "A true walking partnership", pawPointsBonus: 500, threshold: 250),
        DogMilestone(id: "walks_500", type: .walkCount, title: "500 Walks!", subtitle: "Half a thousand walks together", pawPointsBonus: 500, threshold: 500),
        DogMilestone(id: "walks_1000", type: .walkCount, title: "1,000 Walks!", subtitle: "Legendary walking duo!", pawPointsBonus: 500, threshold: 1000),
    ]

    // MARK: - Distance Milestones in meters (matches Android: 10,50,100,250,500,1000,2500,5000 km)
    private static let distanceMilestones: [DogMilestone] = [
        DogMilestone(id: "distance_10km", type: .distance, title: "10km Together!", subtitle: "Your first big distance milestone", pawPointsBonus: 2, threshold: 10_000),
        DogMilestone(id: "distance_50km", type: .distance, title: "50km Together!", subtitle: "That's a marathon and then some", pawPointsBonus: 10, threshold: 50_000),
        DogMilestone(id: "distance_100km", type: .distance, title: "100km Together!", subtitle: "A century of kilometres", pawPointsBonus: 20, threshold: 100_000),
        DogMilestone(id: "distance_250km", type: .distance, title: "250km Together!", subtitle: "Seriously impressive distance", pawPointsBonus: 50, threshold: 250_000),
        DogMilestone(id: "distance_500km", type: .distance, title: "500km Together!", subtitle: "Half a megametre of walks!", pawPointsBonus: 100, threshold: 500_000),
        DogMilestone(id: "distance_1000km", type: .distance, title: "1,000km Together!", subtitle: "One thousand kilometres of adventures", pawPointsBonus: 200, threshold: 1_000_000),
        DogMilestone(id: "distance_2500km", type: .distance, title: "2,500km Together!", subtitle: "An incredible walking journey", pawPointsBonus: 500, threshold: 2_500_000),
        DogMilestone(id: "distance_5000km", type: .distance, title: "5,000km Together!", subtitle: "You've walked across continents!", pawPointsBonus: 500, threshold: 5_000_000),
    ]

    // MARK: - Streak Milestones (matches Android: 7,14,30,60,90,180,365)
    private static let streakMilestones: [DogMilestone] = [
        DogMilestone(id: "streak_7", type: .streak, title: "7-Day Streak!", subtitle: "A whole week of daily walks", pawPointsBonus: 21, threshold: 7),
        DogMilestone(id: "streak_14", type: .streak, title: "14-Day Streak!", subtitle: "Two weeks strong!", pawPointsBonus: 42, threshold: 14),
        DogMilestone(id: "streak_30", type: .streak, title: "30-Day Streak!", subtitle: "A month of daily walks - amazing!", pawPointsBonus: 90, threshold: 30),
        DogMilestone(id: "streak_60", type: .streak, title: "60-Day Streak!", subtitle: "Two months without missing a day", pawPointsBonus: 180, threshold: 60),
        DogMilestone(id: "streak_90", type: .streak, title: "90-Day Streak!", subtitle: "A full quarter of daily walks", pawPointsBonus: 270, threshold: 90),
        DogMilestone(id: "streak_180", type: .streak, title: "180-Day Streak!", subtitle: "Half a year of daily walks!", pawPointsBonus: 500, threshold: 180),
        DogMilestone(id: "streak_365", type: .streak, title: "365-Day Streak!", subtitle: "A full year walking every single day!", pawPointsBonus: 500, threshold: 365),
    ]

    // MARK: - Time Together Milestones in milliseconds (matches Android: 1,3,6,12,24 months)
    private static let oneMonthMs: Int64 = 30 * 24 * 60 * 60 * 1000
    private static let timeMilestones: [DogMilestone] = [
        DogMilestone(id: "time_1m", type: .timeTogether, title: "1 Month Together!", subtitle: "Walking together for a whole month", pawPointsBonus: 20, threshold: 1 * oneMonthMs),
        DogMilestone(id: "time_3m", type: .timeTogether, title: "3 Months Together!", subtitle: "A quarter of a year of adventures", pawPointsBonus: 60, threshold: 3 * oneMonthMs),
        DogMilestone(id: "time_6m", type: .timeTogether, title: "6 Months Together!", subtitle: "Half a year of walks!", pawPointsBonus: 120, threshold: 6 * oneMonthMs),
        DogMilestone(id: "time_12m", type: .timeTogether, title: "1 Year Together!", subtitle: "A full year of walking memories", pawPointsBonus: 240, threshold: 12 * oneMonthMs),
        DogMilestone(id: "time_24m", type: .timeTogether, title: "2 Years Together!", subtitle: "Two years of faithful walks!", pawPointsBonus: 480, threshold: 24 * oneMonthMs),
    ]

    // MARK: - Fun Distance Milestones in meters (matches Android)
    private static let funDistanceMilestones: [DogMilestone] = [
        DogMilestone(id: "fun_42km", type: .funDistance, title: "Marathon Distance!", subtitle: "You've walked a full marathon distance!", pawPointsBonus: 4, threshold: 42_195),
        DogMilestone(id: "fun_200km", type: .funDistance, title: "London to Paris!", subtitle: "You've walked the equivalent of London to Paris", pawPointsBonus: 20, threshold: 200_000),
        DogMilestone(id: "fun_600km", type: .funDistance, title: "Land's End to John o' Groats!", subtitle: "You've walked the length of Great Britain!", pawPointsBonus: 60, threshold: 600_000),
        DogMilestone(id: "fun_1000km", type: .funDistance, title: "The Length of France!", subtitle: "Paris to the Mediterranean on foot", pawPointsBonus: 100, threshold: 1_000_000),
        DogMilestone(id: "fun_1407km", type: .funDistance, title: "The Length of the UK!", subtitle: "From top to bottom of the United Kingdom", pawPointsBonus: 140, threshold: 1_407_000),
        DogMilestone(id: "fun_4000km", type: .funDistance, title: "Coast to Coast USA!", subtitle: "You've walked across America!", pawPointsBonus: 400, threshold: 4_000_000),
        DogMilestone(id: "fun_5000km", type: .funDistance, title: "The Great Wall!", subtitle: "You've walked the length of the Great Wall of China!", pawPointsBonus: 500, threshold: 5_000_000),
    ]

    // MARK: - All Milestones Combined
    static let allMilestones: [DogMilestone] =
        walkCountMilestones + distanceMilestones + streakMilestones + timeMilestones + funDistanceMilestones

    func getDogWalkStats(dogId: String) async throws -> DogWalkStats? {
        let doc = try await db.collection("dogs").document(dogId).getDocument()
        guard let data = doc.data(), let walkStatsData = data["walkStats"] as? [String: Any] else { return nil }
        return try? Firestore.Decoder().decode(DogWalkStats.self, from: walkStatsData)
    }

    func checkMilestones(dogId: String, dogName: String, dogPhotoUrl: String?, stats: DogWalkStats) -> MilestoneCheckResult {
        var newMilestones: [DogMilestone] = []

        for milestone in MilestoneRepository.allMilestones {
            guard !stats.achievedMilestones.contains(milestone.id) else { continue }
            let value: Int64
            switch milestone.type {
            case .walkCount: value = Int64(stats.totalWalks)
            case .distance: value = stats.totalDistanceMeters
            case .streak: value = Int64(stats.currentStreak)
            case .timeTogether:
                if let firstWalk = stats.firstWalkDate {
                    value = Int64(Date().timeIntervalSince1970 * 1000) - firstWalk
                } else {
                    value = 0
                }
            case .funDistance: value = stats.totalDistanceMeters
            }
            if value >= milestone.threshold { newMilestones.append(milestone) }
        }

        var updatedStats = stats
        updatedStats.achievedMilestones.append(contentsOf: newMilestones.map(\.id))

        return MilestoneCheckResult(dogId: dogId, dogName: dogName, dogPhotoUrl: dogPhotoUrl, newMilestones: newMilestones, updatedStats: updatedStats)
    }

    func saveDogWalkStats(dogId: String, stats: DogWalkStats) async throws {
        let encoded = try Firestore.Encoder().encode(stats)
        try await db.collection("dogs").document(dogId).updateData([
            "walkStats": encoded
        ])
    }
}
