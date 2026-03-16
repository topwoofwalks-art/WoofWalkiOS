import Foundation
import FirebaseAuth
import FirebaseFirestore

class MilestoneRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    static let allMilestones: [DogMilestone] = [
        DogMilestone(id: "walks_10", type: .walkCount, title: "10 Walks", subtitle: "First steps together", pawPointsBonus: 50, threshold: 10),
        DogMilestone(id: "walks_50", type: .walkCount, title: "50 Walks", subtitle: "Regular walker", pawPointsBonus: 100, threshold: 50),
        DogMilestone(id: "walks_100", type: .walkCount, title: "100 Walks", subtitle: "Century club", pawPointsBonus: 200, threshold: 100),
        DogMilestone(id: "walks_500", type: .walkCount, title: "500 Walks", subtitle: "Dedicated duo", pawPointsBonus: 500, threshold: 500),
        DogMilestone(id: "dist_10km", type: .distance, title: "10 km", subtitle: "Getting started", pawPointsBonus: 25, threshold: 10000),
        DogMilestone(id: "dist_42km", type: .distance, title: "Marathon", subtitle: "42.2 km together", pawPointsBonus: 100, threshold: 42200),
        DogMilestone(id: "dist_100km", type: .distance, title: "100 km", subtitle: "Century distance", pawPointsBonus: 200, threshold: 100000),
        DogMilestone(id: "dist_500km", type: .distance, title: "500 km", subtitle: "Half millennium", pawPointsBonus: 500, threshold: 500000),
        DogMilestone(id: "streak_7", type: .streak, title: "7 Day Streak", subtitle: "One full week", pawPointsBonus: 50, threshold: 7),
        DogMilestone(id: "streak_30", type: .streak, title: "30 Day Streak", subtitle: "Monthly champion", pawPointsBonus: 150, threshold: 30),
        DogMilestone(id: "streak_100", type: .streak, title: "100 Day Streak", subtitle: "Incredible dedication", pawPointsBonus: 500, threshold: 100),
    ]

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
            case .streak: value = Int64(stats.longestStreak)
            case .timeTogether: value = 0
            case .funDistance: value = 0
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
