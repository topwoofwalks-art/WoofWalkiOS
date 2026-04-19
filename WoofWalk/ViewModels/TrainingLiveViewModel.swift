import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Training Models

struct TrainingSkill: Identifiable {
    let id: String
    let name: String
    let icon: String
}

struct TrainingExercise: Identifiable {
    let id: String
    let name: String
    let attempts: Int
    let successes: Int
    let beforeLevel: Int // 1-5
    let afterLevel: Int  // 1-5
    let notes: String

    var successRate: Double {
        guard attempts > 0 else { return 0 }
        return Double(successes) / Double(attempts)
    }

    var successPercent: Int {
        Int(successRate * 100)
    }

    var levelImproved: Bool {
        afterLevel > beforeLevel
    }
}

struct BehaviourObservation: Identifiable {
    let id: String
    let category: String // "positive", "concern", "note"
    let text: String
    let timestamp: Date

    var icon: String {
        switch category {
        case "positive": return "hand.thumbsup.fill"
        case "concern": return "exclamationmark.triangle.fill"
        default: return "note.text"
        }
    }

    var color: Color {
        switch category {
        case "positive": return Color.success60
        case "concern": return .orange60
        default: return .neutral60
        }
    }
}

struct HomeworkItem: Identifiable {
    let id: String
    let title: String
    let description: String
    let frequency: String // "daily", "3x_week", "weekly"
    let durationMinutes: Int
}

struct TrainingPhoto: Identifiable {
    let id: String
    let url: String
    let caption: String
    let timestamp: Date
}

struct TrainingSummary {
    let overallProgress: String
    let keyWins: [String]
    let areasToWork: [String]
    let nextSessionFocus: String
    let trainerNotes: String
}

// MARK: - ViewModel

@MainActor
class TrainingLiveViewModel: ObservableObject {
    // MARK: - Published State

    @Published var trainerName: String = ""
    @Published var dogName: String = ""
    @Published var status: String = "in_progress"
    @Published var sessionType: String = "" // "obedience", "agility", "behaviour", "puppy"
    @Published var skills: [TrainingSkill] = []
    @Published var exercises: [TrainingExercise] = []
    @Published var observations: [BehaviourObservation] = []
    @Published var homework: [HomeworkItem] = []
    @Published var photos: [TrainingPhoto] = []
    @Published var summary: TrainingSummary?
    @Published var trainerPhone: String?
    @Published var startedAt: Date?
    @Published var isLoading = true
    @Published var error: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private var sessionListener: ListenerRegistration?
    private let sessionId: String

    // MARK: - Init / Deinit

    init(sessionId: String) {
        self.sessionId = sessionId
        startListening()
    }

    deinit {
        sessionListener?.remove()
    }

    // MARK: - Computed Properties

    var isCompleted: Bool {
        status == "completed"
    }

    var statusDisplayText: String {
        switch status {
        case "in_progress": return "In Progress"
        case "completed": return "Completed"
        case "waiting": return "Waiting to Start"
        default: return status.capitalized
        }
    }

    var overallSuccessRate: Double {
        let totalAttempts = exercises.reduce(0) { $0 + $1.attempts }
        let totalSuccesses = exercises.reduce(0) { $0 + $1.successes }
        guard totalAttempts > 0 else { return 0 }
        return Double(totalSuccesses) / Double(totalAttempts)
    }

    var overallSuccessPercent: Int {
        Int(overallSuccessRate * 100)
    }

    var sessionDuration: String {
        guard let start = startedAt else { return "--" }
        let elapsed = Date().timeIntervalSince(start)
        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    var sessionTypeIcon: String {
        switch sessionType {
        case "obedience": return "hand.raised.fill"
        case "agility": return "figure.run"
        case "behaviour": return "brain.head.profile"
        case "puppy": return "pawprint.fill"
        default: return "graduationcap.fill"
        }
    }

    // MARK: - Firestore Listener

    private func startListening() {
        isLoading = true

        sessionListener = db.collection("training_sessions")
            .document(sessionId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    print("[TrainingLiveVM] Listener error: \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    return
                }

                guard let data = snapshot?.data() else {
                    self.error = "Session not found"
                    return
                }

                self.parseSession(data)
            }
    }

    private func parseSession(_ data: [String: Any]) {
        trainerName = data["trainerName"] as? String ?? "Your Trainer"
        dogName = data["dogName"] as? String ?? "Your Dog"
        status = data["status"] as? String ?? "in_progress"
        sessionType = data["sessionType"] as? String ?? ""
        trainerPhone = data["trainerPhone"] as? String

        if let ts = data["startedAt"] as? Timestamp {
            startedAt = ts.dateValue()
        }

        // Parse skills
        if let skillData = data["skills"] as? [[String: Any]] {
            skills = skillData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let name = dict["name"] as? String ?? ""
                let icon = dict["icon"] as? String ?? "star.fill"
                return TrainingSkill(id: id, name: name, icon: icon)
            }
        }

        // Parse exercises
        if let exerciseData = data["exercises"] as? [[String: Any]] {
            exercises = exerciseData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let name = dict["name"] as? String ?? ""
                let attempts = dict["attempts"] as? Int ?? 0
                let successes = dict["successes"] as? Int ?? 0
                let beforeLevel = dict["beforeLevel"] as? Int ?? 1
                let afterLevel = dict["afterLevel"] as? Int ?? 1
                let notes = dict["notes"] as? String ?? ""
                return TrainingExercise(
                    id: id, name: name, attempts: attempts, successes: successes,
                    beforeLevel: beforeLevel, afterLevel: afterLevel, notes: notes
                )
            }
        }

        // Parse observations
        if let obsData = data["observations"] as? [[String: Any]] {
            observations = obsData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let category = dict["category"] as? String ?? "note"
                let text = dict["text"] as? String ?? ""
                let ts = (dict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return BehaviourObservation(id: id, category: category, text: text, timestamp: ts)
            }
        }

        // Parse homework
        if let hwData = data["homework"] as? [[String: Any]] {
            homework = hwData.compactMap { dict in
                let id = dict["id"] as? String ?? UUID().uuidString
                let title = dict["title"] as? String ?? ""
                let description = dict["description"] as? String ?? ""
                let frequency = dict["frequency"] as? String ?? "daily"
                let duration = dict["durationMinutes"] as? Int ?? 10
                return HomeworkItem(id: id, title: title, description: description, frequency: frequency, durationMinutes: duration)
            }
        }

        // Parse photos
        if let photoData = data["photos"] as? [[String: Any]] {
            photos = photoData.compactMap { dict in
                guard let url = dict["url"] as? String else { return nil }
                let id = dict["id"] as? String ?? UUID().uuidString
                let caption = dict["caption"] as? String ?? ""
                let ts = (dict["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return TrainingPhoto(id: id, url: url, caption: caption, timestamp: ts)
            }
            .sorted { $0.timestamp > $1.timestamp }
        }

        // Parse session summary (appears when completed)
        if let summaryData = data["summary"] as? [String: Any] {
            summary = TrainingSummary(
                overallProgress: summaryData["overallProgress"] as? String ?? "",
                keyWins: summaryData["keyWins"] as? [String] ?? [],
                areasToWork: summaryData["areasToWork"] as? [String] ?? [],
                nextSessionFocus: summaryData["nextSessionFocus"] as? String ?? "",
                trainerNotes: summaryData["trainerNotes"] as? String ?? ""
            )
        }
    }
}
