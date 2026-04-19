import Foundation
import Combine
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum LeaderboardType: String, CaseIterable {
    case global = "Global"
    case regional = "Regional"
    case friends = "Friends"
}

enum ProfileUiState {
    case loading
    case success(ProfileData)
    case error(String)
    case leaderboardLoaded([UserProfile])
}

struct ProfileData {
    let user: UserProfile
    let totalWalks: Int
    let totalDistance: Int
    let totalTime: Int
    let contributions: Int
}

struct BadgeWithStatus {
    let badge: Badge
    let isUnlocked: Bool
    let progress: Float
    let currentValue: Int
    let targetValue: Int
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var uiState: ProfileUiState = .loading
    @Published var badges: [BadgeWithStatus] = []
    @Published var userProfile: UserProfile?
    @Published var friends: [UserProfile] = []
    @Published var weeklyWalkData: [Int] = [0, 0, 0, 0, 0, 0, 0]
    @Published var recentWalks: [RecentWalkDisplay] = []

    private let userRepository: UserRepository
    private let statsRepository: StatsRepository
    private var cancellables = Set<AnyCancellable>()

    init(userRepository: UserRepository = UserRepository(),
         statsRepository: StatsRepository = StatsRepository()) {
        self.userRepository = userRepository
        self.statsRepository = statsRepository
        loadProfileData()
        observeBadgeProgress()
    }

    private func loadProfileData() {
        uiState = .loading

        userRepository.getUserProfile()
            .combineLatest(statsRepository.getAllCompletedSessions())
            .sink { completion in
                if case .failure(let error) = completion {
                    self.uiState = .error(error.localizedDescription)
                }
            } receiveValue: { [weak self] user, sessions in
                guard let self = self, let user = user else { return }

                self.userProfile = user

                Task {
                    do {
                        let totalDistance = try await self.statsRepository.getTotalDistance()
                        let totalDuration = try await self.statsRepository.getTotalDuration()
                        let totalWalks = try await self.statsRepository.getTotalWalkCount()

                        self.uiState = .success(ProfileData(
                            user: user,
                            totalWalks: totalWalks,
                            totalDistance: Int(totalDistance),
                            totalTime: Int(totalDuration),
                            contributions: 0
                        ))
                    } catch {
                        self.uiState = .error(error.localizedDescription)
                    }
                }
            }
            .store(in: &cancellables)

        userRepository.getFriends()
            .sink { _ in } receiveValue: { [weak self] friends in
                self?.friends = friends
            }
            .store(in: &cancellables)

        statsRepository.getWeeklyWalkCounts()
            .sink { _ in } receiveValue: { [weak self] dailyCounts in
                var weekArray = [Int](repeating: 0, count: 7)
                for dayCount in dailyCounts {
                    let index = (dayCount.dayOfWeek + 6) % 7
                    if index < 7 {
                        weekArray[index] = dayCount.walkCount
                    }
                }
                self?.weeklyWalkData = weekArray
            }
            .store(in: &cancellables)
    }

    private func observeBadgeProgress() {
        userRepository.getUserProfile()
            .sink { _ in } receiveValue: { [weak self] user in
                guard let self = self else { return }

                Task {
                    do {
                        let totalWalks = try await self.statsRepository.getTotalWalkCount()
                        let totalDistance = try await self.statsRepository.getTotalDistance()

                        let stats = WalkStatsSummary(
                            totalWalks: totalWalks,
                            totalDistanceMeters: totalDistance,
                            totalTimeMinutes: 0
                        )

                        self.badges = self.checkBadgeUnlocks(user: user, stats: stats)
                    } catch {
                        print("Error observing badge progress: \(error)")
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func checkBadgeUnlocks(user: UserProfile?, stats: WalkStatsSummary) -> [BadgeWithStatus] {
        guard let user = user else { return [] }

        return BadgeDefinitions.allBadges.map { badge in
            let isUnlocked = user.badges.contains(badge.id)
            let progress = calculateBadgeProgress(badge: badge, user: user, stats: stats)

            return BadgeWithStatus(
                badge: badge,
                isUnlocked: isUnlocked,
                progress: progress,
                currentValue: Int(progress * Float(badge.unlockCriteria.targetValue)),
                targetValue: badge.unlockCriteria.targetValue
            )
        }
    }

    private func calculateBadgeProgress(badge: Badge, user: UserProfile, stats: WalkStatsSummary) -> Float {
        if user.badges.contains(badge.id) { return 1.0 }

        switch badge.unlockCriteria.type {
        case .walksCompleted:
            let current = stats.totalWalks
            return min(Float(current) / Float(badge.unlockCriteria.targetValue), 1.0)
        case .distanceTotal:
            let current = Int(stats.totalDistanceMeters)
            return min(Float(current) / Float(badge.unlockCriteria.targetValue), 1.0)
        case .poisCreated, .votesGiven, .timeOfDay, .special:
            return 0.0
        }
    }

    func updateProfile(username: String? = nil, bio: String? = nil) {
        Task {
            do {
                var updates: [String: Any] = [:]
                if let username = username {
                    updates["username"] = username
                }
                if let bio = bio {
                    updates["bio"] = bio
                }

                try await userRepository.updateUserProfile(updates: updates)
                print("Profile updated successfully")
            } catch {
                print("Error updating profile: \(error)")
            }
        }
    }

    /// Dog CRUD routes through `DogRepository` (writes to `/dogs/{dogId}`).
    /// The legacy `UserRepository.addDogProfile` / `updateDogProfile` /
    /// `removeDogProfile` shims that wrote to `users/{uid}.dogs[]` are
    /// gone — the embedded array is now a `DogProfilePublic` projection
    /// maintained by the `onDogWrite` Cloud Function.

    func addDogProfile(dog: DogProfile) {
        Task {
            do {
                try await DogRepository().addDog(dog.toUnifiedDog())
                print("Dog profile added: \(dog.name)")
            } catch {
                print("Error adding dog profile: \(error)")
            }
        }
    }

    func updateDogProfile(dogId: String, dog: DogProfile) {
        Task {
            do {
                try await DogRepository().updateDog(dogId: dogId, dog: dog.toUnifiedDog())
                print("Dog profile updated: \(dog.name)")
            } catch {
                print("Error updating dog profile: \(error)")
            }
        }
    }

    func removeDogProfile(dogId: String) {
        Task {
            do {
                try await DogRepository().removeDog(dogId: dogId)
                print("Dog profile removed: \(dogId)")
            } catch {
                print("Error removing dog profile: \(error)")
            }
        }
    }

    func loadLeaderboard(type: LeaderboardType) {
        Task {
            do {
                let users: [UserProfile]

                switch type {
                case .global:
                    users = try await userRepository.getLeaderboard()
                case .regional:
                    let regionCode = userProfile?.regionCode
                    users = try await userRepository.getLeaderboard(regionCode: regionCode)
                case .friends:
                    let friendIds = friends.compactMap { $0.id }
                    users = try await userRepository.getFriendsLeaderboard(friendIds: friendIds)
                }

                self.uiState = .leaderboardLoaded(users)
            } catch {
                self.uiState = .error(error.localizedDescription)
            }
        }
    }

    func calculateLevel(pawPoints: Int) -> Int {
        return Int(floor(sqrt(Double(pawPoints) / 100.0)) + 1)
    }
}

struct StatsRepository {
    private let db = Firestore.firestore()

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    private func walksCollection() -> CollectionReference? {
        guard let uid = userId else { return nil }
        return db.collection("users").document(uid).collection("walks")
    }

    func getAllCompletedSessions() -> AnyPublisher<[WalkSession], Error> {
        guard let collection = walksCollection() else {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        return Future { promise in
            collection.order(by: "startedAt", descending: true).limit(to: 100)
                .getDocuments { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        let sessions = snapshot?.documents.compactMap { doc -> WalkSession? in
                            let data = doc.data()
                            guard let dist = data["distanceMeters"] as? Double,
                                  let dur = data["durationSec"] as? Int else { return nil }
                            let startedAt = (data["startedAt"] as? Timestamp)?.dateValue() ?? Date()
                            return WalkSession(
                                id: doc.documentID,
                                sessionId: doc.documentID,
                                startedAt: startedAt,
                                distanceMeters: dist,
                                durationSec: dur
                            )
                        } ?? []
                        promise(.success(sessions))
                    }
                }
        }.eraseToAnyPublisher()
    }

    func getTotalDistance() async throws -> Double {
        guard let collection = walksCollection() else { return 0 }
        let snapshot = try await collection.getDocuments()
        return snapshot.documents.reduce(0.0) { sum, doc in
            sum + (doc.data()["distanceMeters"] as? Double ?? 0)
        }
    }

    func getTotalDuration() async throws -> Int {
        guard let collection = walksCollection() else { return 0 }
        let snapshot = try await collection.getDocuments()
        return snapshot.documents.reduce(0) { sum, doc in
            sum + (doc.data()["durationSec"] as? Int ?? 0)
        }
    }

    func getTotalWalkCount() async throws -> Int {
        guard let collection = walksCollection() else { return 0 }
        let snapshot = try await collection.getDocuments()
        return snapshot.documents.count
    }

    func getWeeklyWalkCounts() -> AnyPublisher<[DailyWalkCount], Error> {
        guard let collection = walksCollection() else {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return Future { promise in
            collection.whereField("startedAt", isGreaterThan: Timestamp(date: weekAgo))
                .getDocuments { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                    } else {
                        var counts: [Int: Int] = [:]
                        let calendar = Calendar.current
                        for doc in snapshot?.documents ?? [] {
                            if let ts = doc.data()["startedAt"] as? Timestamp {
                                let weekday = calendar.component(.weekday, from: ts.dateValue())
                                counts[weekday, default: 0] += 1
                            }
                        }
                        let result = counts.map { DailyWalkCount(dayOfWeek: $0.key, walkCount: $0.value) }
                            .sorted(by: { $0.dayOfWeek < $1.dayOfWeek })
                        promise(.success(result))
                    }
                }
        }.eraseToAnyPublisher()
    }
}

// WalkSession is defined in ViewModels/WalkViewModel.swift

struct DailyWalkCount {
    let dayOfWeek: Int
    let walkCount: Int
}
