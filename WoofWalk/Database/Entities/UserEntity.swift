#if false
import SwiftData
import Foundation
import FirebaseFirestore

@Model
final class UserEntity {
    @Attribute(.unique) var id: String
    var username: String
    var email: String
    var photoUrl: String?
    var pawPoints: Int
    var level: Int
    var badgesJson: String
    var dogsJson: String
    var createdAt: Date
    var regionCode: String
    var lastSyncedAt: Date
    var bio: String
    var displayName: String?
    var role: String?
    var walkStreakJson: String?
    var leagueTier: String?
    var leagueGroupId: String?
    var leagueWeekId: String?
    var marketingOptIn: Bool
    var totalWalks: Int
    var totalDistanceMeters: Double

    init(
        id: String,
        username: String,
        email: String,
        photoUrl: String? = nil,
        pawPoints: Int = 0,
        level: Int = 1,
        badgesJson: String = "[]",
        dogsJson: String = "[]",
        createdAt: Date = Date(),
        regionCode: String,
        lastSyncedAt: Date = Date(),
        bio: String = "",
        displayName: String? = nil,
        role: String? = nil,
        walkStreakJson: String? = nil,
        leagueTier: String? = nil,
        leagueGroupId: String? = nil,
        leagueWeekId: String? = nil,
        marketingOptIn: Bool = false,
        totalWalks: Int = 0,
        totalDistanceMeters: Double = 0.0
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.photoUrl = photoUrl
        self.pawPoints = pawPoints
        self.level = level
        self.badgesJson = badgesJson
        self.dogsJson = dogsJson
        self.createdAt = createdAt
        self.regionCode = regionCode
        self.lastSyncedAt = lastSyncedAt
        self.bio = bio
        self.displayName = displayName
        self.role = role
        self.walkStreakJson = walkStreakJson
        self.leagueTier = leagueTier
        self.leagueGroupId = leagueGroupId
        self.leagueWeekId = leagueWeekId
        self.marketingOptIn = marketingOptIn
        self.totalWalks = totalWalks
        self.totalDistanceMeters = totalDistanceMeters
    }

    func toDomain() -> UserProfile {
        let decoder = JSONDecoder()
        let badges = (try? decoder.decode([String].self, from: badgesJson.data(using: .utf8) ?? Data())) ?? []
        let dogs = (try? decoder.decode([DogProfile].self, from: dogsJson.data(using: .utf8) ?? Data())) ?? []

        return UserProfile(
            id: id,
            username: username,
            email: email,
            photoUrl: photoUrl,
            pawPoints: pawPoints,
            level: level,
            badges: badges,
            dogs: dogs,
            createdAt: Timestamp(date: createdAt),
            regionCode: regionCode,
            totalWalks: totalWalks,
            totalDistanceMeters: totalDistanceMeters
        )
    }

    func walkStreak() -> WalkStreak? {
        guard let json = walkStreakJson, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WalkStreak.self, from: data)
    }

    static func fromDomain(_ user: UserProfile) -> UserEntity {
        let encoder = JSONEncoder()
        let badgesJson = (try? encoder.encode(user.badges)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let dogsJson = (try? encoder.encode(user.dogs)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return UserEntity(
            id: user.id ?? UUID().uuidString,
            username: user.username,
            email: user.email,
            photoUrl: user.photoUrl,
            pawPoints: user.pawPoints,
            level: user.level,
            badgesJson: badgesJson,
            dogsJson: dogsJson,
            createdAt: user.createdAt ?? Date(),
            regionCode: user.regionCode,
            lastSyncedAt: Date(),
            totalWalks: user.totalWalks,
            totalDistanceMeters: user.totalDistanceMeters
        )
    }
}

#endif
