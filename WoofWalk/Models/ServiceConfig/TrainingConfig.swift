import Foundation

// MARK: - Training Service Configuration

/// A training specialism offered by the business (e.g. "Puppy Training", "Reactivity").
struct TrainingSpecialism: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var iconName: String?
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        iconName: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.isActive = isActive
    }
}

/// A type of training session (e.g. "1-to-1", "Group Class", "Home Visit").
struct TrainingSessionType: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var durationMinutes: Int
    var price: Double
    var maxDogs: Int
    var isGroup: Bool
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        durationMinutes: Int = 60,
        price: Double = 0.0,
        maxDogs: Int = 1,
        isGroup: Bool = false,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.durationMinutes = durationMinutes
        self.price = price
        self.maxDogs = maxDogs
        self.isGroup = isGroup
        self.isActive = isActive
    }
}

/// A structured training programme (e.g. "6-Week Puppy Course").
struct TrainingProgramme: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var sessionCount: Int
    var totalPrice: Double
    var sessionTypeId: String?
    var specialismId: String?
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        sessionCount: Int = 6,
        totalPrice: Double = 0.0,
        sessionTypeId: String? = nil,
        specialismId: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sessionCount = sessionCount
        self.totalPrice = totalPrice
        self.sessionTypeId = sessionTypeId
        self.specialismId = specialismId
        self.isActive = isActive
    }
}

/// A training exercise in the library that trainers can assign.
struct TrainingExercise: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String?
    var difficulty: String
    var category: String?
    var steps: [String]
    var videoUrl: String?

    init(
        id: String = UUID().uuidString,
        name: String = "",
        description: String? = nil,
        difficulty: String = SkillLevel.beginner.rawValue,
        category: String? = nil,
        steps: [String] = [],
        videoUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.difficulty = difficulty
        self.category = category
        self.steps = steps
        self.videoUrl = videoUrl
    }
}

/// Training method/approach used by the business.
enum TrainingMethod: String, Codable, CaseIterable {
    case positiveReinforcement = "POSITIVE_REINFORCEMENT"
    case clicker = "CLICKER"
    case balancedTraining = "BALANCED_TRAINING"
    case markerBased = "MARKER_BASED"
    case gamesBased = "GAMES_BASED"

    var displayName: String {
        switch self {
        case .positiveReinforcement: return "Positive Reinforcement"
        case .clicker: return "Clicker Training"
        case .balancedTraining: return "Balanced Training"
        case .markerBased: return "Marker-Based"
        case .gamesBased: return "Games-Based"
        }
    }

    static func from(string: String?) -> TrainingMethod {
        guard let string = string else { return .positiveReinforcement }
        return TrainingMethod(rawValue: string) ?? .positiveReinforcement
    }
}

/// Full training service configuration for a business.
struct TrainingServiceConfig: Codable, Equatable {
    var specialisms: [TrainingSpecialism]
    var sessionTypes: [TrainingSessionType]
    var programmes: [TrainingProgramme]
    var exerciseLibrary: [TrainingExercise]
    var methods: [String]

    /// Typed training methods
    var trainingMethods: [TrainingMethod] {
        methods.compactMap { TrainingMethod(rawValue: $0) }
    }

    init(
        specialisms: [TrainingSpecialism] = [],
        sessionTypes: [TrainingSessionType] = [],
        programmes: [TrainingProgramme] = [],
        exerciseLibrary: [TrainingExercise] = [],
        methods: [String] = [TrainingMethod.positiveReinforcement.rawValue]
    ) {
        self.specialisms = specialisms
        self.sessionTypes = sessionTypes
        self.programmes = programmes
        self.exerciseLibrary = exerciseLibrary
        self.methods = methods
    }
}
