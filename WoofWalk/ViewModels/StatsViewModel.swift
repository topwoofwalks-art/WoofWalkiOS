#if false
// StatsViewModel.swift - disabled due to broken type references (Timestamp vs Date, type-checker timeout)

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class StatsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var totalWalks: Int = 0
    @Published var totalDistance: Double = 0
    @Published var totalTime: Int = 0
    @Published var averageSpeed: Double = 0
    @Published var contributions: Int = 0

    @Published var weeklyWalkData: [Int] = Array(repeating: 0, count: 7)
    @Published var weeklyStats: [PeriodStats] = []
    @Published var monthlyStats: [PeriodStats] = []

    @Published var walksPerDog: [String: Int] = [:]
    @Published var distancePerDog: [String: Double] = [:]
    @Published var favoriteRoutes: [RouteStats] = []
    @Published var mostVisitedPOIs: [POIStats] = []

    @Published var personalRecords = PersonalRecords()
    @Published var achievements: [Achievement] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0

    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    func loadStatistics() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isLoading = true
        errorMessage = nil

        do {
            async let walks = fetchAllWalks(userId: userId)
            async let pois = fetchUserPOIs(userId: userId)

            let (allWalks, userPOIs) = try await (walks, pois)

            calculateOverallStats(from: allWalks)
            calculateWeeklyData(from: allWalks)
            calculatePeriodStats(from: allWalks)
            calculateDogStats(from: allWalks)
            calculatePersonalRecords(from: allWalks)
            calculateStreaks(from: allWalks)
            contributions = userPOIs.count

            checkAchievements()

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func fetchAllWalks(userId: String) async throws -> [WalkHistory] {
        let snapshot = try await db.collection("walks")
            .whereField("userId", isEqualTo: userId)
            .whereField("endedAt", isNotEqualTo: NSNull())
            .order(by: "endedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: WalkHistory.self)
        }
    }

    private func fetchUserPOIs(userId: String) async throws -> [POI] {
        let snapshot = try await db.collection("pois")
            .whereField("createdBy", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: POI.self)
        }
    }

    private func calculateOverallStats(from walks: [WalkHistory]) {
        totalWalks = walks.count
        totalDistance = walks.reduce(0) { $0 + $1.distanceMeters }
        totalTime = walks.reduce(0) { $0 + $1.durationSec }

        if totalTime > 0 && totalDistance > 0 {
            let timeHours = Double(totalTime) / 3600.0
            let distanceKm = totalDistance / 1000.0
            averageSpeed = distanceKm / timeHours
        }
    }

    private func calculateWeeklyData(from walks: [WalkHistory]) {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!

        var dailyCounts = Array(repeating: 0, count: 7)

        for walk in walks {
            guard let walkDate = walk.startedAt else { continue }

            if walkDate >= weekStart && walkDate <= today {
                let dayIndex = calendar.dateComponents([.day], from: weekStart, to: walkDate).day ?? 0
                if dayIndex >= 0 && dayIndex < 7 {
                    dailyCounts[dayIndex] += 1
                }
            }
        }

        weeklyWalkData = dailyCounts
    }

    private func calculatePeriodStats(from walks: [WalkHistory]) {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "'Week' w, yyyy"
        let weeklyGroups = Dictionary(grouping: walks) { walk -> String in
            guard let date = walk.startedAt else { return "" }
            return dateFormatter.string(from: date)
        }

        weeklyStats = weeklyGroups.map { period, periodWalks in
            PeriodStats(
                period: period,
                distanceMeters: periodWalks.reduce(0) { $0 + $1.distanceMeters },
                durationSec: periodWalks.reduce(0) { $0 + $1.durationSec },
                walkCount: periodWalks.count
            )
        }.sorted { $0.period > $1.period }

        dateFormatter.dateFormat = "MMMM yyyy"
        let monthlyGroups = Dictionary(grouping: walks) { walk -> String in
            guard let date = walk.startedAt else { return "" }
            return dateFormatter.string(from: date)
        }

        monthlyStats = monthlyGroups.map { period, periodWalks in
            PeriodStats(
                period: period,
                distanceMeters: periodWalks.reduce(0) { $0 + $1.distanceMeters },
                durationSec: periodWalks.reduce(0) { $0 + $1.durationSec },
                walkCount: periodWalks.count
            )
        }.sorted { $0.period > $1.period }
    }

    private func calculateDogStats(from walks: [WalkHistory]) {
        var walkCounts: [String: Int] = [:]
        var distances: [String: Double] = [:]

        for walk in walks {
            for dogId in walk.dogIds {
                walkCounts[dogId, default: 0] += 1
                distances[dogId, default: 0] += walk.distanceMeters
            }
        }

        walksPerDog = walkCounts
        distancePerDog = distances
    }

    private func calculatePersonalRecords(from walks: [WalkHistory]) {
        guard !walks.isEmpty else { return }

        let longestDistance = walks.max(by: { $0.distanceMeters < $1.distanceMeters })
        let longestDuration = walks.max(by: { $0.durationSec < $1.durationSec })

        var fastestPace = Double.greatestFiniteMagnitude
        for walk in walks where walk.durationSec > 0 {
            let pace = Double(walk.durationSec) / (walk.distanceMeters / 1000.0)
            if pace < fastestPace {
                fastestPace = pace
            }
        }

        let calendar = Calendar.current
        let walksByDay = Dictionary(grouping: walks) { walk -> Date in
            guard let date = walk.startedAt else { return Date.distantPast }
            return calendar.startOfDay(for: date)
        }

        let mostActiveDay = walksByDay.max(by: { $0.value.count < $1.value.count })

        personalRecords = PersonalRecords(
            longestWalkDistance: longestDistance?.distanceMeters ?? 0,
            longestWalkTime: longestDuration?.durationSec ?? 0,
            fastestPace: fastestPace == Double.greatestFiniteMagnitude ? 0 : fastestPace,
            mostActiveDay: mostActiveDay?.key ?? Date()
        )
    }

    private func calculateStreaks(from walks: [WalkHistory]) {
        guard !walks.isEmpty else {
            currentStreak = 0
            longestStreak = 0
            return
        }

        let calendar = Calendar.current
        let sortedWalks = walks.sorted { ($0.startedAt ?? Date.distantPast) > ($1.startedAt ?? Date.distantPast) }

        var dates = Set<Date>()
        for walk in sortedWalks {
            if let date = walk.startedAt {
                dates.insert(calendar.startOfDay(for: date))
            }
        }

        let sortedDates = dates.sorted(by: >)

        var current = 0
        var longest = 0
        var temp = 1

        for i in 0..<sortedDates.count - 1 {
            let diff = calendar.dateComponents([.day], from: sortedDates[i+1], to: sortedDates[i]).day ?? 0

            if diff == 1 {
                temp += 1
            } else {
                longest = max(longest, temp)
                temp = 1
            }
        }
        longest = max(longest, temp)

        if let firstDate = sortedDates.first {
            let today = calendar.startOfDay(for: Date())
            let diff = calendar.dateComponents([.day], from: firstDate, to: today).day ?? 0

            if diff <= 1 {
                var streakTemp = 1
                for i in 0..<sortedDates.count - 1 {
                    let dayDiff = calendar.dateComponents([.day], from: sortedDates[i+1], to: sortedDates[i]).day ?? 0
                    if dayDiff == 1 {
                        streakTemp += 1
                    } else {
                        break
                    }
                }
                current = streakTemp
            }
        }

        currentStreak = current
        longestStreak = longest
    }

    private func checkAchievements() {
        achievements = AchievementDefinitions.allAchievements.map { definition in
            let progress = calculateAchievementProgress(for: definition)
            return Achievement(
                id: definition.id,
                name: definition.name,
                description: definition.description,
                icon: definition.icon,
                category: definition.category,
                isUnlocked: progress >= 1.0,
                progress: progress,
                targetValue: definition.targetValue
            )
        }
    }

    private func calculateAchievementProgress(for definition: AchievementDefinition) -> Double {
        switch definition.type {
        case .walksCompleted:
            return min(1.0, Double(totalWalks) / Double(definition.targetValue))
        case .distanceTotal:
            return min(1.0, totalDistance / Double(definition.targetValue))
        case .streakDays:
            return min(1.0, Double(currentStreak) / Double(definition.targetValue))
        case .poisCreated:
            return min(1.0, Double(contributions) / Double(definition.targetValue))
        case .dogParksVisited:
            return 0.0
        case .earlyMorning:
            return 0.0
        case .lateNight:
            return 0.0
        }
    }

    func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.2f km", meters / 1000.0)
        }
    }

    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    func formatSpeed(_ kmh: Double) -> String {
        return String(format: "%.1f km/h", kmh)
    }
}

struct PeriodStats: Identifiable {
    let id = UUID()
    let period: String
    let distanceMeters: Double
    let durationSec: Int
    let walkCount: Int
}

struct RouteStats: Identifiable {
    let id = UUID()
    let routeName: String
    let timesWalked: Int
    let totalDistance: Double
}

struct POIStats: Identifiable {
    let id: String
    let name: String
    let visitCount: Int
    let lastVisited: Date?
}

struct PersonalRecords {
    var longestWalkDistance: Double = 0
    var longestWalkTime: Int = 0
    var fastestPace: Double = 0
    var mostActiveDay: Date = Date()
}

struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let isUnlocked: Bool
    let progress: Double
    let targetValue: Int
}

enum AchievementCategory: String, Codable {
    case walks
    case distance
    case social
    case special
}

enum AchievementType {
    case walksCompleted
    case distanceTotal
    case streakDays
    case poisCreated
    case dogParksVisited
    case earlyMorning
    case lateNight
}

struct AchievementDefinition {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let type: AchievementType
    let targetValue: Int
}

struct AchievementDefinitions {
    static let allAchievements: [AchievementDefinition] = [
        AchievementDefinition(
            id: "first_walk",
            name: "First Steps",
            description: "Complete your first walk",
            icon: "pawprint.fill",
            category: .walks,
            type: .walksCompleted,
            targetValue: 1
        ),
        AchievementDefinition(
            id: "walk_10",
            name: "Getting Started",
            description: "Complete 10 walks",
            icon: "figure.walk",
            category: .walks,
            type: .walksCompleted,
            targetValue: 10
        ),
        AchievementDefinition(
            id: "walk_50",
            name: "Regular Walker",
            description: "Complete 50 walks",
            icon: "figure.walk.circle",
            category: .walks,
            type: .walksCompleted,
            targetValue: 50
        ),
        AchievementDefinition(
            id: "walk_100",
            name: "Century Club",
            description: "Complete 100 walks",
            icon: "star.fill",
            category: .walks,
            type: .walksCompleted,
            targetValue: 100
        ),
        AchievementDefinition(
            id: "walk_5km",
            name: "5K Explorer",
            description: "Walk a total of 5 kilometers",
            icon: "map.fill",
            category: .distance,
            type: .distanceTotal,
            targetValue: 5000
        ),
        AchievementDefinition(
            id: "walk_10km",
            name: "10K Trekker",
            description: "Walk a total of 10 kilometers",
            icon: "figure.hiking",
            category: .distance,
            type: .distanceTotal,
            targetValue: 10000
        ),
        AchievementDefinition(
            id: "walk_marathon",
            name: "Marathon Master",
            description: "Walk a total of 42 kilometers",
            icon: "medal.fill",
            category: .distance,
            type: .distanceTotal,
            targetValue: 42000
        ),
        AchievementDefinition(
            id: "walk_100km",
            name: "Ultra Walker",
            description: "Walk a total of 100 kilometers",
            icon: "trophy.fill",
            category: .distance,
            type: .distanceTotal,
            targetValue: 100000
        ),
        AchievementDefinition(
            id: "streak_7",
            name: "Week Warrior",
            description: "Walk for 7 consecutive days",
            icon: "calendar",
            category: .walks,
            type: .streakDays,
            targetValue: 7
        ),
        AchievementDefinition(
            id: "streak_30",
            name: "Month Master",
            description: "Walk for 30 consecutive days",
            icon: "calendar.badge.plus",
            category: .walks,
            type: .streakDays,
            targetValue: 30
        ),
        AchievementDefinition(
            id: "contributor",
            name: "Contributor",
            description: "Add 10 POIs to the map",
            icon: "mappin.and.ellipse",
            category: .social,
            type: .poisCreated,
            targetValue: 10
        ),
        AchievementDefinition(
            id: "explorer",
            name: "Explorer",
            description: "Visit 10 different dog parks",
            icon: "map.circle.fill",
            category: .special,
            type: .dogParksVisited,
            targetValue: 10
        ),
        AchievementDefinition(
            id: "early_bird",
            name: "Early Bird",
            description: "Complete 5 walks before 7 AM",
            icon: "sunrise.fill",
            category: .special,
            type: .earlyMorning,
            targetValue: 5
        ),
        AchievementDefinition(
            id: "night_owl",
            name: "Night Owl",
            description: "Complete 5 walks after 9 PM",
            icon: "moon.stars.fill",
            category: .special,
            type: .lateNight,
            targetValue: 5
        )
    ]
}
#endif
