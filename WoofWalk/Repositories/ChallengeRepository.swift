import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class ChallengeRepository {
    static let shared = ChallengeRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    func getActiveChallenges() -> AnyPublisher<[Challenge], Error> {
        let publisher = PassthroughSubject<[Challenge], Error>()
        db.collection("challenges")
            .whereField("isActive", isEqualTo: true)
            .order(by: "startDate", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error { publisher.send(completion: .failure(error)); return }
                let challenges = (snapshot?.documents ?? []).compactMap { try? $0.data(as: Challenge.self) }
                publisher.send(challenges)
            }
        return publisher.eraseToAnyPublisher()
    }

    /// Fetch active challenges as a one-shot async array (for use in walk completion).
    func fetchActiveChallenges() async throws -> [Challenge] {
        let snapshot = try await db.collection("challenges")
            .whereField("isActive", isEqualTo: true)
            .order(by: "startDate", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Challenge.self) }
    }

    func getChallenge(byId challengeId: String) async throws -> Challenge? {
        let doc = try await db.collection("challenges").document(challengeId).getDocument()
        return try? doc.data(as: Challenge.self)
    }

    func joinChallenge(_ challengeId: String) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        let userDoc = try await db.collection("users").document(uid).getDocument()
        let userName = userDoc.data()?["username"] as? String ?? "User"
        let userAvatar = userDoc.data()?["photoUrl"] as? String

        let participant = ChallengeParticipant(userId: uid, userName: userName, userAvatar: userAvatar, progress: 0, rank: 0, joinedAt: Timestamp())
        try db.collection("challenges").document(challengeId).collection("participants").document(uid).setData(from: participant)
        try await db.collection("challenges").document(challengeId).updateData([
            "participantIds": FieldValue.arrayUnion([uid]),
            "participantCount": FieldValue.increment(Int64(1))
        ])
    }

    func updateProgress(challengeId: String, progress: Double) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("challenges").document(challengeId).collection("participants").document(uid).updateData(["progress": progress])
    }

    /// Update challenge progress using a Firestore transaction for safety.
    /// progressDelta is added to the current progress. If progress reaches target, completedAt is set.
    func updateProgressWithTransaction(challengeId: String, progressDelta: Double) async throws {
        guard let uid = auth.currentUser?.uid else { return }

        let participantRef = db.collection("challenges").document(challengeId)
            .collection("participants").document(uid)
        let challengeRef = db.collection("challenges").document(challengeId)

        try await db.runTransaction { transaction, errorPointer in
            let participantSnap: DocumentSnapshot
            let challengeSnap: DocumentSnapshot
            do {
                participantSnap = try transaction.getDocument(participantRef)
                challengeSnap = try transaction.getDocument(challengeRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            let currentProgress = participantSnap.data()?["progress"] as? Double ?? 0.0
            let newProgress = currentProgress + progressDelta
            transaction.updateData(["progress": newProgress], forDocument: participantRef)

            let target = challengeSnap.data()?["target"] as? Double ?? 0.0
            let alreadyCompleted = participantSnap.data()?["completedAt"] != nil
            if newProgress >= target && !alreadyCompleted {
                transaction.updateData(["completedAt": Timestamp()], forDocument: participantRef)
            }

            return nil
        }
    }

    /// Get the current user's progress for a specific challenge.
    func getUserProgress(challengeId: String) async -> Double {
        guard let uid = auth.currentUser?.uid else { return 0.0 }
        do {
            let doc = try await db.collection("challenges").document(challengeId)
                .collection("participants").document(uid).getDocument()
            return doc.data()?["progress"] as? Double ?? 0.0
        } catch {
            print("[ChallengeRepository] Error fetching user progress: \(error)")
            return 0.0
        }
    }

    func getLeaderboard(challengeId: String) async throws -> [ChallengeParticipant] {
        let snapshot = try await db.collection("challenges").document(challengeId).collection("participants")
            .order(by: "progress", descending: true)
            .limit(to: 50)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ChallengeParticipant.self) }
    }

    // MARK: - Default Challenges

    /// Auto-generate default challenges if no active challenges exist.
    /// Creates daily, weekly, monthly, and special challenges with appropriate date ranges.
    func ensureDefaultChallengesExist() async {
        do {
            let existing = try await db.collection("challenges")
                .whereField("isActive", isEqualTo: true)
                .limit(to: 1)
                .getDocuments()

            guard existing.documents.isEmpty else {
                print("[ChallengeRepository] Active challenges already exist, skipping generation")
                return
            }

            print("[ChallengeRepository] No active challenges found, generating defaults")

            let now = Date()
            let calendar = Calendar.current

            // Daily: ends at midnight tonight
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

            // Weekly: ends next Sunday night
            var endOfWeekDate = now
            if let nextSunday = calendar.nextDate(after: now, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime) {
                endOfWeekDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: nextSunday) ?? nextSunday
            }

            // Monthly: ends last day of month
            let range = calendar.range(of: .day, in: .month, for: now)!
            var endOfMonthComponents = calendar.dateComponents([.year, .month], from: now)
            endOfMonthComponents.day = range.upperBound - 1
            endOfMonthComponents.hour = 23
            endOfMonthComponents.minute = 59
            endOfMonthComponents.second = 59
            let endOfMonth = calendar.date(from: endOfMonthComponents) ?? now

            // Special: 7-day window
            let sevenDaysLater = calendar.date(byAdding: .day, value: 7, to: now) ?? now

            let startTimestamp = Timestamp()

            let defaults: [Challenge] = [
                Challenge(
                    title: "Walk 2km today",
                    description: "Complete a total of 2km walking today",
                    type: .distance,
                    target: 2.0,
                    unit: "km",
                    startDate: startTimestamp,
                    endDate: Timestamp(date: endOfDay),
                    iconEmoji: "\u{1F6B6}",
                    category: .daily,
                    isActive: true,
                    createdBy: "system"
                ),
                Challenge(
                    title: "Complete 5 walks this week",
                    description: "Take your dog out for 5 separate walks",
                    type: .walksCount,
                    target: 5.0,
                    unit: "walks",
                    startDate: startTimestamp,
                    endDate: Timestamp(date: endOfWeekDate),
                    iconEmoji: "\u{1F43E}",
                    category: .weekly,
                    isActive: true,
                    createdBy: "system"
                ),
                Challenge(
                    title: "Walk 50km this month",
                    description: "Accumulate 50km of walking distance this month",
                    type: .distance,
                    target: 50.0,
                    unit: "km",
                    startDate: startTimestamp,
                    endDate: Timestamp(date: endOfMonth),
                    iconEmoji: "\u{1F31F}",
                    category: .monthly,
                    isActive: true,
                    createdBy: "system"
                ),
                Challenge(
                    title: "7-day streak challenge",
                    description: "Walk your dog every day for 7 consecutive days",
                    type: .streak,
                    target: 7.0,
                    unit: "days",
                    startDate: startTimestamp,
                    endDate: Timestamp(date: sevenDaysLater),
                    iconEmoji: "\u{1F525}",
                    category: .special,
                    isActive: true,
                    createdBy: "system"
                )
            ]

            for challenge in defaults {
                try db.collection("challenges").addDocument(from: challenge)
            }
            print("[ChallengeRepository] Generated \(defaults.count) default challenges")
        } catch {
            print("[ChallengeRepository] Error ensuring default challenges: \(error)")
        }
    }

    // MARK: - Challenge Progress After Walk

    /// Update all active challenges the user has joined after completing a walk.
    /// Matches Android WalkTrackingViewModel.updateChallengeProgress().
    func updateChallengeProgressAfterWalk(
        distanceMeters: Double,
        durationSeconds: Int,
        currentStreak: Int
    ) async {
        guard let uid = auth.currentUser?.uid else { return }

        do {
            let activeChallenges = try await fetchActiveChallenges()

            for challenge in activeChallenges {
                guard let challengeId = challenge.id,
                      challenge.participantIds.contains(uid) else { continue }

                let progressDelta: Double
                switch challenge.type {
                case .distance:
                    progressDelta = distanceMeters / 1000.0 // convert to km
                case .walksCount:
                    progressDelta = 1.0
                case .duration:
                    progressDelta = Double(durationSeconds) / 60.0 // convert to minutes
                case .streak:
                    // For streak challenges, set progress to current streak (absolute, not delta)
                    let currentProgress = await getUserProgress(challengeId: challengeId)
                    let newStreakValue = Double(currentStreak)
                    progressDelta = newStreakValue > currentProgress ? (newStreakValue - currentProgress) : 0.0
                case .speed:
                    // For speed challenges, track average speed in km/h
                    let durationHours = Double(durationSeconds) / 3600.0
                    let distanceKm = distanceMeters / 1000.0
                    if durationHours > 0 {
                        let avgSpeedKmh = distanceKm / durationHours
                        let currentProgress = await getUserProgress(challengeId: challengeId)
                        progressDelta = avgSpeedKmh > currentProgress ? (avgSpeedKmh - currentProgress) : 0.0
                    } else {
                        progressDelta = 0.0
                    }
                }

                if progressDelta > 0 {
                    try await updateProgressWithTransaction(challengeId: challengeId, progressDelta: progressDelta)
                    print("[ChallengeRepository] Updated challenge \(challengeId) progress by \(String(format: "%.2f", progressDelta))")
                }
            }
        } catch {
            print("[ChallengeRepository] Error updating challenge progress: \(error)")
        }
    }
}
