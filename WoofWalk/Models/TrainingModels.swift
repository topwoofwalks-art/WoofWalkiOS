import Foundation

// MARK: - Training Skill

/// Skills that can be trained during a session.
enum TrainingSkill: String, Codable, CaseIterable {
    case sit = "SIT"
    case stay = "STAY"
    case recall = "RECALL"
    case looseLead = "LOOSE_LEAD"
    case leaveIt = "LEAVE_IT"
    case down = "DOWN"
    case heel = "HEEL"
    case wait = "WAIT"
    case settle = "SETTLE"
    case crateTraining = "CRATE_TRAINING"
    case socialisation = "SOCIALISATION"
    case reactivity = "REACTIVITY"
    case separationAnxiety = "SEPARATION_ANXIETY"
    case custom = "CUSTOM"

    var displayName: String {
        switch self {
        case .sit: return "Sit"
        case .stay: return "Stay"
        case .recall: return "Recall"
        case .looseLead: return "Loose Lead"
        case .leaveIt: return "Leave It"
        case .down: return "Down"
        case .heel: return "Heel"
        case .wait: return "Wait"
        case .settle: return "Settle"
        case .crateTraining: return "Crate Training"
        case .socialisation: return "Socialisation"
        case .reactivity: return "Reactivity"
        case .separationAnxiety: return "Separation Anxiety"
        case .custom: return "Custom"
        }
    }

    static func from(string: String?) -> TrainingSkill {
        guard let string = string else { return .custom }
        return TrainingSkill(rawValue: string) ?? .custom
    }
}

// MARK: - Skill Level

/// Skill proficiency level for before/after assessment.
enum SkillLevel: String, Codable, CaseIterable {
    case none = "NONE"
    case beginner = "BEGINNER"
    case intermediate = "INTERMEDIATE"
    case advanced = "ADVANCED"
    case mastered = "MASTERED"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .mastered: return "Mastered"
        }
    }

    var ordinalValue: Int {
        switch self {
        case .none: return 0
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .mastered: return 4
        }
    }

    static func from(string: String?) -> SkillLevel {
        guard let string = string else { return .none }
        return SkillLevel(rawValue: string) ?? .none
    }
}

// MARK: - Focus Level

/// Focus/attention level during training.
enum FocusLevel: String, Codable, CaseIterable {
    case easilyDistracted = "EASILY_DISTRACTED"
    case moderate = "MODERATE"
    case excellent = "EXCELLENT"

    var displayName: String {
        switch self {
        case .easilyDistracted: return "Easily distracted"
        case .moderate: return "Moderate"
        case .excellent: return "Excellent"
        }
    }

    static func from(string: String?) -> FocusLevel {
        guard let string = string else { return .moderate }
        return FocusLevel(rawValue: string) ?? .moderate
    }
}

// MARK: - Energy Level

/// Energy level during training.
enum EnergyLevel: String, Codable, CaseIterable {
    case low = "LOW"
    case moderate = "MODERATE"
    case high = "HIGH"
    case hyperactive = "HYPERACTIVE"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .hyperactive: return "Hyperactive"
        }
    }

    static func from(string: String?) -> EnergyLevel {
        guard let string = string else { return .moderate }
        return EnergyLevel(rawValue: string) ?? .moderate
    }
}

// MARK: - Exercise Rating

/// Exercise performance rating.
enum ExerciseRating: String, Codable, CaseIterable {
    case poor = "POOR"
    case fair = "FAIR"
    case good = "GOOD"
    case excellent = "EXCELLENT"

    var displayName: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }

    var stars: Int {
        switch self {
        case .poor: return 1
        case .fair: return 2
        case .good: return 3
        case .excellent: return 4
        }
    }

    static func from(string: String?) -> ExerciseRating {
        guard let string = string else { return .good }
        return ExerciseRating(rawValue: string) ?? .good
    }

    static func fromStars(_ stars: Int) -> ExerciseRating {
        switch stars {
        case ...1: return .poor
        case 2: return .fair
        case 3: return .good
        default: return .excellent
        }
    }
}

// MARK: - Training Session Status

enum TrainingSessionStatus: String, Codable {
    case scheduled = "SCHEDULED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"

    static func from(string: String?) -> TrainingSessionStatus {
        guard let string = string else { return .scheduled }
        return TrainingSessionStatus(rawValue: string) ?? .scheduled
    }
}

// MARK: - Exercise Entry

/// An individual exercise tracked during a training session.
struct ExerciseEntry: Identifiable, Codable, Equatable {
    let id: String
    var skill: String
    var customSkillName: String
    var totalAttempts: Int
    var successfulAttempts: Int
    var rating: String
    var notes: String
    var skillLevelBefore: String
    var skillLevelAfter: String

    var trainingSkill: TrainingSkill {
        TrainingSkill.from(string: skill)
    }

    var exerciseRating: ExerciseRating {
        ExerciseRating.from(string: rating)
    }

    var beforeLevel: SkillLevel {
        SkillLevel.from(string: skillLevelBefore)
    }

    var afterLevel: SkillLevel {
        SkillLevel.from(string: skillLevelAfter)
    }

    var skillDisplayName: String {
        if trainingSkill == .custom {
            return customSkillName
        }
        return trainingSkill.displayName
    }

    var successRate: Float {
        guard totalAttempts > 0 else { return 0.0 }
        return Float(successfulAttempts) / Float(totalAttempts)
    }

    var successRatePercent: Int {
        Int(successRate * 100)
    }

    var hasProgressed: Bool {
        afterLevel.ordinalValue > beforeLevel.ordinalValue
    }

    func toMap() -> [String: Any?] {
        return [
            "id": id,
            "skill": skill,
            "customSkillName": customSkillName,
            "totalAttempts": totalAttempts,
            "successfulAttempts": successfulAttempts,
            "rating": rating,
            "notes": notes,
            "skillLevelBefore": skillLevelBefore,
            "skillLevelAfter": skillLevelAfter
        ]
    }

    init(
        id: String = UUID().uuidString,
        skill: String = TrainingSkill.custom.rawValue,
        customSkillName: String = "",
        totalAttempts: Int = 0,
        successfulAttempts: Int = 0,
        rating: String = ExerciseRating.good.rawValue,
        notes: String = "",
        skillLevelBefore: String = SkillLevel.none.rawValue,
        skillLevelAfter: String = SkillLevel.none.rawValue
    ) {
        self.id = id
        self.skill = skill
        self.customSkillName = customSkillName
        self.totalAttempts = totalAttempts
        self.successfulAttempts = successfulAttempts
        self.rating = rating
        self.notes = notes
        self.skillLevelBefore = skillLevelBefore
        self.skillLevelAfter = skillLevelAfter
    }
}

// MARK: - Homework Item

/// A homework exercise assigned to the owner.
struct HomeworkItem: Identifiable, Codable, Equatable {
    let id: String
    var exercise: String
    var frequency: String
    var tips: String

    func toMap() -> [String: Any] {
        return [
            "id": id,
            "exercise": exercise,
            "frequency": frequency,
            "tips": tips
        ]
    }

    init(
        id: String = UUID().uuidString,
        exercise: String = "",
        frequency: String = "",
        tips: String = ""
    ) {
        self.id = id
        self.exercise = exercise
        self.frequency = frequency
        self.tips = tips
    }
}

// MARK: - Behaviour Observations

/// Behaviour observations recorded during a training session.
struct BehaviourObservations: Codable, Equatable {
    var focusLevel: String
    var energyLevel: String
    var reactivityNotes: String
    var confidenceNotes: String

    var focus: FocusLevel {
        FocusLevel.from(string: focusLevel)
    }

    var energy: EnergyLevel {
        EnergyLevel.from(string: energyLevel)
    }

    func toMap() -> [String: Any] {
        return [
            "focusLevel": focusLevel,
            "energyLevel": energyLevel,
            "reactivityNotes": reactivityNotes,
            "confidenceNotes": confidenceNotes
        ]
    }

    init(
        focusLevel: String = FocusLevel.moderate.rawValue,
        energyLevel: String = EnergyLevel.moderate.rawValue,
        reactivityNotes: String = "",
        confidenceNotes: String = ""
    ) {
        self.focusLevel = focusLevel
        self.energyLevel = energyLevel
        self.reactivityNotes = reactivityNotes
        self.confidenceNotes = confidenceNotes
    }
}

// MARK: - Training Session

/// Full training session data.
struct TrainingSession: Identifiable, Codable, Equatable {
    let id: String
    var trainerId: String
    var clientId: String
    var clientName: String
    var clientPhone: String
    var dogId: String
    var dogName: String
    var breed: String
    var trainingFocus: String
    var status: TrainingSessionStatus
    var scheduledAt: Int64
    var startedAt: Int64?
    var completedAt: Int64?
    var duration: Int64
    var lessonPlan: [String]
    var exercises: [ExerciseEntry]
    var behaviourObservations: BehaviourObservations
    var homework: [HomeworkItem]
    var photoUrls: [String]
    var sessionNotes: String
    var nextSessionRecommendations: String
    var reportSentToClient: Bool
    var createdAt: Int64
    var updatedAt: Int64

    var lessonPlanSkills: [TrainingSkill] {
        lessonPlan.map { TrainingSkill.from(string: $0) }
    }

    func toMap() -> [String: Any?] {
        return [
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
            "lessonPlan": lessonPlan,
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

    init(
        id: String = "",
        trainerId: String = "",
        clientId: String = "",
        clientName: String = "",
        clientPhone: String = "",
        dogId: String = "",
        dogName: String = "",
        breed: String = "",
        trainingFocus: String = "",
        status: TrainingSessionStatus = .scheduled,
        scheduledAt: Int64 = 0,
        startedAt: Int64? = nil,
        completedAt: Int64? = nil,
        duration: Int64 = 0,
        lessonPlan: [String] = [],
        exercises: [ExerciseEntry] = [],
        behaviourObservations: BehaviourObservations = BehaviourObservations(),
        homework: [HomeworkItem] = [],
        photoUrls: [String] = [],
        sessionNotes: String = "",
        nextSessionRecommendations: String = "",
        reportSentToClient: Bool = false,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.trainerId = trainerId
        self.clientId = clientId
        self.clientName = clientName
        self.clientPhone = clientPhone
        self.dogId = dogId
        self.dogName = dogName
        self.breed = breed
        self.trainingFocus = trainingFocus
        self.status = status
        self.scheduledAt = scheduledAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
        self.lessonPlan = lessonPlan
        self.exercises = exercises
        self.behaviourObservations = behaviourObservations
        self.homework = homework
        self.photoUrls = photoUrls
        self.sessionNotes = sessionNotes
        self.nextSessionRecommendations = nextSessionRecommendations
        self.reportSentToClient = reportSentToClient
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
