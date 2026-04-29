import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// All enum and data-model types (SkillLevel, FocusLevel, EnergyLevel, ExerciseRating,
// TrainingSessionStatus, TrainingSkill, ExerciseEntry, HomeworkItem,
// BehaviourObservations) live canonically in `Models/TrainingModels.swift`.
// Only `TrainingSessionData` (the local mutable runtime form) and the
// view model class are defined here.

struct TrainingSessionData {
    let id: String
    var trainerId: String = ""
    var clientId: String = ""
    var clientName: String = ""
    var clientPhone: String = ""
    var dogId: String = ""
    var dogName: String = ""
    var breed: String = ""
    var trainingFocus: String = ""
    var status: TrainingSessionStatus = .scheduled
    var scheduledAt: Int64 = 0
    var startedAt: Int64?
    var completedAt: Int64?
    var duration: Int64 = 0
    var lessonPlan: [TrainingSkill] = []
    var exercises: [ExerciseEntry] = []
    var behaviourObservations: BehaviourObservations = BehaviourObservations()
    var homework: [HomeworkItem] = []
    var photoUrls: [String] = []
    var sessionNotes: String = ""
    var nextSessionRecommendations: String = ""
    var reportSentToClient: Bool = false
    var createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    var updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

    func toMap() -> [String: Any?] {
        [
            "trainerId": trainerId,
            "clientId": clientId,
            "clientName": clientName,
            "clientPhone": clientPhone,
            "dogId": dogId,
            "dogName": dogName,
            "breed": breed,
            "trainingFocus": trainingFocus,
            "status": status.rawValue,
            "scheduledAt": scheduledAt,
            "startedAt": startedAt,
            "completedAt": completedAt,
            "duration": duration,
            "lessonPlan": lessonPlan.map { $0.rawValue },
            "exercises": exercises.map { $0.toMap() },
            "behaviourObservations": behaviourObservations.toMap(),
            "homework": homework.map { $0.toMap() },
            "photoUrls": photoUrls,
            "sessionNotes": sessionNotes,
            "nextSessionRecommendations": nextSessionRecommendations,
            "reportSentToClient": reportSentToClient,
            "createdAt": createdAt,
            "updatedAt": Int64(Date().timeIntervalSince1970 * 1000)
        ]
    }
}

// MARK: - ViewModel

@MainActor
class TrainingSessionViewModel: ObservableObject {

    // MARK: - Published State

    @Published var session: TrainingSessionData?
    @Published var elapsedTime: Int64 = 0
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var sessionListener: ListenerRegistration?
    private var timer: Timer?
    private let sessionId: String

    // MARK: - Init / Deinit

    init(sessionId: String) {
        self.sessionId = sessionId
        if !sessionId.isEmpty {
            observeSession()
            startTimer()
        }
    }

    deinit {
        sessionListener?.remove()
        timer?.invalidate()
    }

    // MARK: - Observe Session

    private func observeSession() {
        sessionListener = db.collection("training_sessions")
            .document(sessionId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("[TrainingSession] Listener error: \(error)")
                    self.error = error.localizedDescription
                    return
                }

                guard let doc = snapshot, doc.exists, let data = doc.data() else { return }

                self.session = self.parseSession(docId: doc.documentID, data: data)
            }
    }

    /// Ensures the current user is a participant in this session before any write.
    /// Trainers and the session's client are allowed; everyone else is refused.
    private func canMutate() -> Bool {
        guard let uid = Auth.auth().currentUser?.uid, let s = session else { return false }
        if uid == s.trainerId || uid == s.clientId { return true }
        self.error = "Not authorized to modify this training session"
        print("[TrainingSession] Refusing mutation: uid=\(uid) not trainer=\(s.trainerId) or client=\(s.clientId)")
        return false
    }

    private func parseSession(docId: String, data: [String: Any]) -> TrainingSessionData {
        let lessonPlanRaw = data["lessonPlan"] as? [String] ?? []
        let lessonPlan = lessonPlanRaw.map { TrainingSkill.from(string: $0) }

        let exercisesData = data["exercises"] as? [[String: Any]] ?? []
        let exercises = exercisesData.map { m in
            ExerciseEntry(
                id: m["id"] as? String ?? UUID().uuidString,
                skill: TrainingSkill.from(string: m["skill"] as? String),
                customSkillName: m["customSkillName"] as? String ?? "",
                totalAttempts: m["totalAttempts"] as? Int ?? 0,
                successfulAttempts: m["successfulAttempts"] as? Int ?? 0,
                rating: ExerciseRating.from(string: m["rating"] as? String),
                notes: m["notes"] as? String ?? "",
                skillLevelBefore: SkillLevel.from(string: m["skillLevelBefore"] as? String),
                skillLevelAfter: SkillLevel.from(string: m["skillLevelAfter"] as? String)
            )
        }

        let obsData = data["behaviourObservations"] as? [String: Any] ?? [:]
        let observations = BehaviourObservations(
            focusLevel: FocusLevel.from(string: obsData["focusLevel"] as? String),
            energyLevel: EnergyLevel.from(string: obsData["energyLevel"] as? String),
            reactivityNotes: obsData["reactivityNotes"] as? String ?? "",
            confidenceNotes: obsData["confidenceNotes"] as? String ?? ""
        )

        let homeworkData = data["homework"] as? [[String: Any]] ?? []
        let homework = homeworkData.map { m in
            HomeworkItem(
                id: m["id"] as? String ?? UUID().uuidString,
                exercise: m["exercise"] as? String ?? "",
                frequency: m["frequency"] as? String ?? "",
                tips: m["tips"] as? String ?? ""
            )
        }

        return TrainingSessionData(
            id: docId,
            trainerId: data["trainerId"] as? String ?? "",
            clientId: data["clientId"] as? String ?? "",
            clientName: data["clientName"] as? String ?? "",
            clientPhone: data["clientPhone"] as? String ?? "",
            dogId: data["dogId"] as? String ?? "",
            dogName: data["dogName"] as? String ?? "",
            breed: data["breed"] as? String ?? "",
            trainingFocus: data["trainingFocus"] as? String ?? "",
            status: TrainingSessionStatus.from(string: data["status"] as? String),
            scheduledAt: data["scheduledAt"] as? Int64 ?? 0,
            startedAt: data["startedAt"] as? Int64,
            completedAt: data["completedAt"] as? Int64,
            duration: data["duration"] as? Int64 ?? 0,
            lessonPlan: lessonPlan,
            exercises: exercises,
            behaviourObservations: observations,
            homework: homework,
            photoUrls: data["photoUrls"] as? [String] ?? [],
            sessionNotes: data["sessionNotes"] as? String ?? "",
            nextSessionRecommendations: data["nextSessionRecommendations"] as? String ?? "",
            reportSentToClient: data["reportSentToClient"] as? Bool ?? false,
            createdAt: data["createdAt"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000),
            updatedAt: data["updatedAt"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        )
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let startedAt = self.session?.startedAt,
                      self.session?.status == .inProgress else { return }
                self.elapsedTime = Int64(Date().timeIntervalSince1970 * 1000) - startedAt
            }
        }
    }

    // MARK: - Lesson Plan

    func updateLessonPlan(_ skills: [TrainingSkill]) {
        guard canMutate() else { return }
        Task {
            do {
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["lessonPlan": skills.map { $0.rawValue }])
            } catch {
                self.error = "Failed to update lesson plan: \(error.localizedDescription)"
                print("[TrainingSession] Failed to update lesson plan: \(error)")
            }
        }
    }

    // MARK: - Exercise Tracking

    func addExercise(_ exercise: ExerciseEntry) {
        guard canMutate() else { return }
        Task {
            do {
                guard let current = session else { return }
                let updated = current.exercises + [exercise]
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["exercises": updated.map { $0.toMap() }])
            } catch {
                self.error = "Failed to add exercise: \(error.localizedDescription)"
                print("[TrainingSession] Failed to add exercise: \(error)")
            }
        }
    }

    func updateExercise(_ exercise: ExerciseEntry) {
        guard canMutate() else { return }
        Task {
            do {
                guard let current = session else { return }
                let updated = current.exercises.map { $0.id == exercise.id ? exercise : $0 }
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["exercises": updated.map { $0.toMap() }])
            } catch {
                self.error = "Failed to update exercise: \(error.localizedDescription)"
                print("[TrainingSession] Failed to update exercise: \(error)")
            }
        }
    }

    func removeExercise(_ exerciseId: String) {
        guard canMutate() else { return }
        Task {
            do {
                guard let current = session else { return }
                let updated = current.exercises.filter { $0.id != exerciseId }
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["exercises": updated.map { $0.toMap() }])
            } catch {
                self.error = "Failed to remove exercise: \(error.localizedDescription)"
                print("[TrainingSession] Failed to remove exercise: \(error)")
            }
        }
    }

    // MARK: - Behaviour Observations

    func updateBehaviourObservations(_ observations: BehaviourObservations) {
        guard canMutate() else { return }
        Task {
            do {
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["behaviourObservations": observations.toMap()])
            } catch {
                self.error = "Failed to save observations: \(error.localizedDescription)"
                print("[TrainingSession] Failed to update observations: \(error)")
            }
        }
    }

    // MARK: - Homework

    func addHomework(_ item: HomeworkItem) {
        guard canMutate() else { return }
        Task {
            do {
                guard let current = session else { return }
                let updated = current.homework + [item]
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["homework": updated.map { $0.toMap() }])
            } catch {
                self.error = "Failed to add homework: \(error.localizedDescription)"
                print("[TrainingSession] Failed to add homework: \(error)")
            }
        }
    }

    func removeHomework(_ homeworkId: String) {
        guard canMutate() else { return }
        Task {
            do {
                guard let current = session else { return }
                let updated = current.homework.filter { $0.id != homeworkId }
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["homework": updated.map { $0.toMap() }])
            } catch {
                self.error = "Failed to remove homework: \(error.localizedDescription)"
                print("[TrainingSession] Failed to remove homework: \(error)")
            }
        }
    }

    // MARK: - Photos

    func addPhotoUrl(_ url: String) {
        guard canMutate() else { return }
        Task {
            do {
                guard let current = session else { return }
                let updated = current.photoUrls + [url]
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["photoUrls": updated])
            } catch {
                self.error = "Failed to add photo: \(error.localizedDescription)"
                print("[TrainingSession] Failed to add photo: \(error)")
            }
        }
    }

    // MARK: - Session Notes

    func updateSessionNotes(_ notes: String) {
        guard canMutate() else { return }
        Task {
            do {
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["sessionNotes": notes])
            } catch {
                self.error = "Failed to save notes: \(error.localizedDescription)"
                print("[TrainingSession] Failed to update notes: \(error)")
            }
        }
    }

    func updateNextSessionRecommendations(_ recommendations: String) {
        guard canMutate() else { return }
        Task {
            do {
                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData(["nextSessionRecommendations": recommendations])
            } catch {
                self.error = "Failed to save recommendations: \(error.localizedDescription)"
                print("[TrainingSession] Failed to update recommendations: \(error)")
            }
        }
    }

    // MARK: - Complete Session

    func completeSession() {
        guard canMutate() else { return }
        isSaving = true

        Task {
            do {
                let now = Int64(Date().timeIntervalSince1970 * 1000)
                let duration = session?.startedAt.map { now - $0 } ?? 0

                try await db.collection("training_sessions")
                    .document(sessionId)
                    .updateData([
                        "status": TrainingSessionStatus.completed.rawValue,
                        "completedAt": now,
                        "duration": duration,
                        "reportSentToClient": true,
                        "updatedAt": now
                    ])

                isSaving = false
                print("[TrainingSession] Session completed: \(sessionId)")
            } catch {
                self.error = "Failed to complete session: \(error.localizedDescription)"
                isSaving = false
                print("[TrainingSession] Failed to complete session: \(error)")
            }
        }
    }

    // MARK: - Report Generation

    func generateReport() -> String {
        guard let session = session else { return "" }

        var lines: [String] = []
        lines.append("Training Session Report")
        lines.append("Dog: \(session.dogName) (\(session.breed))")
        lines.append("Client: \(session.clientName)")
        lines.append("Focus: \(session.trainingFocus)")
        lines.append("Duration: \(formatDuration(elapsedTime))")
        lines.append("")

        if !session.exercises.isEmpty {
            lines.append("--- Exercises ---")
            for exercise in session.exercises {
                lines.append("\(exercise.skillDisplayName): \(exercise.successRatePercent)% success (\(exercise.successfulAttempts)/\(exercise.totalAttempts))")
                if exercise.hasProgressed {
                    lines.append("  Progress: \(exercise.skillLevelBefore.displayName) -> \(exercise.skillLevelAfter.displayName)")
                }
            }
            lines.append("")
        }

        lines.append("--- Behaviour ---")
        lines.append("Focus: \(session.behaviourObservations.focusLevel.displayName)")
        lines.append("Energy: \(session.behaviourObservations.energyLevel.displayName)")
        if !session.behaviourObservations.reactivityNotes.isEmpty {
            lines.append("Reactivity: \(session.behaviourObservations.reactivityNotes)")
        }
        if !session.behaviourObservations.confidenceNotes.isEmpty {
            lines.append("Confidence: \(session.behaviourObservations.confidenceNotes)")
        }

        if !session.homework.isEmpty {
            lines.append("")
            lines.append("--- Homework ---")
            for hw in session.homework {
                lines.append("- \(hw.exercise) (\(hw.frequency))")
                if !hw.tips.isEmpty {
                    lines.append("  Tip: \(hw.tips)")
                }
            }
        }

        if !session.sessionNotes.isEmpty {
            lines.append("")
            lines.append("Notes: \(session.sessionNotes)")
        }

        if !session.nextSessionRecommendations.isEmpty {
            lines.append("")
            lines.append("Next session: \(session.nextSessionRecommendations)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    func clearError() { error = nil }

    func formatDuration(_ ms: Int64) -> String {
        let totalSeconds = ms / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
