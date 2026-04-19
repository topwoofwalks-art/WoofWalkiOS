import Foundation

// MARK: - Daycare Update Type

/// Types of activity events that can be logged during a daycare session.
enum DaycareUpdateType: String, Codable, CaseIterable {
    case feedBreakfast = "FEED_BREAKFAST"
    case feedLunch = "FEED_LUNCH"
    case feedSnack = "FEED_SNACK"
    case water = "WATER"
    case napStart = "NAP_START"
    case napEnd = "NAP_END"
    case playSoloIndoor = "PLAY_SOLO_INDOOR"
    case playSoloOutdoor = "PLAY_SOLO_OUTDOOR"
    case playGroupIndoor = "PLAY_GROUP_INDOOR"
    case playGroupOutdoor = "PLAY_GROUP_OUTDOOR"
    case bathroomPee = "BATHROOM_PEE"
    case bathroomPoo = "BATHROOM_POO"
    case socialisation = "SOCIALISATION"
    case temperament = "TEMPERAMENT"
    case photo = "PHOTO"
    case note = "NOTE"
    case incident = "INCIDENT"

    var displayName: String {
        switch self {
        case .feedBreakfast: return "Breakfast"
        case .feedLunch: return "Lunch"
        case .feedSnack: return "Snack"
        case .water: return "Water"
        case .napStart: return "Nap Started"
        case .napEnd: return "Nap Ended"
        case .playSoloIndoor: return "Solo Play (Indoor)"
        case .playSoloOutdoor: return "Solo Play (Outdoor)"
        case .playGroupIndoor: return "Group Play (Indoor)"
        case .playGroupOutdoor: return "Group Play (Outdoor)"
        case .bathroomPee: return "Pee"
        case .bathroomPoo: return "Poo"
        case .socialisation: return "Socialisation"
        case .temperament: return "Temperament Check"
        case .photo: return "Photo"
        case .note: return "Note"
        case .incident: return "Incident"
        }
    }

    var iconName: String {
        switch self {
        case .feedBreakfast: return "fork.knife"
        case .feedLunch: return "fork.knife"
        case .feedSnack: return "birthday.cake"
        case .water: return "drop.fill"
        case .napStart: return "bed.double.fill"
        case .napEnd: return "sun.max.fill"
        case .playSoloIndoor: return "sportscourt.fill"
        case .playSoloOutdoor: return "leaf.fill"
        case .playGroupIndoor: return "person.3.fill"
        case .playGroupOutdoor: return "tree.fill"
        case .bathroomPee: return "drop.fill"
        case .bathroomPoo: return "leaf.circle.fill"
        case .socialisation: return "heart.fill"
        case .temperament: return "brain.head.profile"
        case .photo: return "camera.fill"
        case .note: return "note.text"
        case .incident: return "exclamationmark.triangle.fill"
        }
    }

    static func from(string: String) -> DaycareUpdateType {
        return DaycareUpdateType(rawValue: string) ?? .note
    }
}

// MARK: - Dog Temperament

/// Temperament / mood options for temperament checks.
enum DogTemperament: String, Codable, CaseIterable {
    case happy = "HAPPY"
    case anxious = "ANXIOUS"
    case tired = "TIRED"
    case energetic = "ENERGETIC"
    case calm = "CALM"
    case playful = "PLAYFUL"

    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .anxious: return "Anxious"
        case .tired: return "Tired"
        case .energetic: return "Energetic"
        case .calm: return "Calm"
        case .playful: return "Playful"
        }
    }

    var emoji: String {
        switch self {
        case .happy: return "\u{1F603}"
        case .anxious: return "\u{1F61F}"
        case .tired: return "\u{1F634}"
        case .energetic: return "\u{1F525}"
        case .calm: return "\u{263A}\u{FE0F}"
        case .playful: return "\u{1F973}"
        }
    }
}

// MARK: - Daycare Incident Type

/// Incident types specific to daycare.
enum DaycareIncidentType: String, Codable, CaseIterable {
    case injury = "INJURY"
    case illness = "ILLNESS"
    case fight = "FIGHT"
    case escapeAttempt = "ESCAPE_ATTEMPT"
    case propertyDamage = "PROPERTY_DAMAGE"
    case behaviouralIssue = "BEHAVIOURAL_ISSUE"
    case feedingRefused = "FEEDING_REFUSED"
    case allergicReaction = "ALLERGIC_REACTION"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .injury: return "Injury"
        case .illness: return "Illness"
        case .fight: return "Fight"
        case .escapeAttempt: return "Escape Attempt"
        case .propertyDamage: return "Property Damage"
        case .behaviouralIssue: return "Behavioural Issue"
        case .feedingRefused: return "Feeding Refused"
        case .allergicReaction: return "Allergic Reaction"
        case .other: return "Other"
        }
    }
}

// MARK: - Daycare Incident Severity

/// Severity levels for daycare incidents.
enum DaycareIncidentSeverity: String, Codable, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
}

// MARK: - Daycare Session Status

enum DaycareSessionStatus: String, Codable {
    case scheduled = "SCHEDULED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
}

// MARK: - Daycare Event

/// A single logged event in the daycare timeline.
struct DaycareEvent: Identifiable, Codable, Equatable {
    let id: String
    let sessionId: String
    var dogId: String?
    var dogName: String?
    let timestamp: Int64
    let type: String
    var note: String?
    var photoUri: String?
    var temperament: String?
    var napDurationMinutes: Int?

    var updateType: DaycareUpdateType {
        DaycareUpdateType.from(string: type)
    }

    var dogTemperament: DogTemperament? {
        guard let temperament = temperament else { return nil }
        return DogTemperament(rawValue: temperament)
    }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        dogId: String? = nil,
        dogName: String? = nil,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        type: String,
        note: String? = nil,
        photoUri: String? = nil,
        temperament: String? = nil,
        napDurationMinutes: Int? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.dogId = dogId
        self.dogName = dogName
        self.timestamp = timestamp
        self.type = type
        self.note = note
        self.photoUri = photoUri
        self.temperament = temperament
        self.napDurationMinutes = napDurationMinutes
    }
}

// MARK: - Daycare Incident

/// Incident logged during daycare.
struct DaycareIncident: Identifiable, Codable, Equatable {
    let id: String
    let sessionId: String
    var dogId: String?
    var dogName: String?
    let type: String
    let severity: String
    let description: String
    var actionTaken: String?
    let timestamp: Int64
    var photoUri: String?

    var incidentType: DaycareIncidentType {
        DaycareIncidentType(rawValue: type) ?? .other
    }

    var incidentSeverity: DaycareIncidentSeverity {
        DaycareIncidentSeverity(rawValue: severity) ?? .low
    }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        dogId: String? = nil,
        dogName: String? = nil,
        type: String,
        severity: String,
        description: String,
        actionTaken: String? = nil,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        photoUri: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.dogId = dogId
        self.dogName = dogName
        self.type = type
        self.severity = severity
        self.description = description
        self.actionTaken = actionTaken
        self.timestamp = timestamp
        self.photoUri = photoUri
    }
}

// MARK: - Daycare Dog

/// A dog checked into the daycare facility.
struct DaycareDog: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    var breed: String?
    var photoUrl: String?
    let ownerName: String
    var ownerPhone: String?
    var specialInstructions: String?
    var feedingInstructions: String?
    var medicationInstructions: String?
    var currentTemperament: String
    var isNapping: Bool
    var napStartTime: Int64?
    var eventCount: Int

    var temperament: DogTemperament {
        DogTemperament(rawValue: currentTemperament) ?? .happy
    }

    init(
        id: String,
        name: String,
        breed: String? = nil,
        photoUrl: String? = nil,
        ownerName: String,
        ownerPhone: String? = nil,
        specialInstructions: String? = nil,
        feedingInstructions: String? = nil,
        medicationInstructions: String? = nil,
        currentTemperament: String = DogTemperament.happy.rawValue,
        isNapping: Bool = false,
        napStartTime: Int64? = nil,
        eventCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.breed = breed
        self.photoUrl = photoUrl
        self.ownerName = ownerName
        self.ownerPhone = ownerPhone
        self.specialInstructions = specialInstructions
        self.feedingInstructions = feedingInstructions
        self.medicationInstructions = medicationInstructions
        self.currentTemperament = currentTemperament
        self.isNapping = isNapping
        self.napStartTime = napStartTime
        self.eventCount = eventCount
    }
}

// MARK: - Daycare Session

/// The full daycare session.
struct DaycareSession: Identifiable, Codable, Equatable {
    let id: String
    let bookingId: String
    let clientName: String
    var clientPhone: String?
    var facilityName: String?
    var dogs: [DaycareDog]
    var events: [DaycareEvent]
    var incidents: [DaycareIncident]
    var photos: [String]
    var sessionNotes: String?
    var startedAt: Date?
    var scheduledEndAt: Date?
    var endedAt: Date?
    var status: DaycareSessionStatus
    var specialInstructions: String?

    var isActive: Bool {
        status == .inProgress
    }

    var elapsedMinutes: Int {
        guard let start = startedAt else { return 0 }
        let end = endedAt ?? Date()
        return Int(end.timeIntervalSince(start) / 60.0)
    }

    var totalSessionMinutes: Int {
        guard let start = startedAt else { return 480 }
        let end = scheduledEndAt ?? start.addingTimeInterval(8 * 3600)
        return Int(end.timeIntervalSince(start) / 60.0)
    }

    var progressPercent: Float {
        let total = totalSessionMinutes
        guard total > 0 else { return 0.0 }
        return min(max(Float(elapsedMinutes) / Float(total), 0.0), 1.0)
    }

    var elapsedFormatted: String {
        let hours = elapsedMinutes / 60
        let minutes = elapsedMinutes % 60
        return "\(hours)h \(minutes)m"
    }

    var remainingFormatted: String {
        let remaining = max(totalSessionMinutes - elapsedMinutes, 0)
        let hours = remaining / 60
        let minutes = remaining % 60
        return "\(hours)h \(minutes)m"
    }

    init(
        id: String,
        bookingId: String,
        clientName: String,
        clientPhone: String? = nil,
        facilityName: String? = nil,
        dogs: [DaycareDog] = [],
        events: [DaycareEvent] = [],
        incidents: [DaycareIncident] = [],
        photos: [String] = [],
        sessionNotes: String? = nil,
        startedAt: Date? = nil,
        scheduledEndAt: Date? = nil,
        endedAt: Date? = nil,
        status: DaycareSessionStatus = .scheduled,
        specialInstructions: String? = nil
    ) {
        self.id = id
        self.bookingId = bookingId
        self.clientName = clientName
        self.clientPhone = clientPhone
        self.facilityName = facilityName
        self.dogs = dogs
        self.events = events
        self.incidents = incidents
        self.photos = photos
        self.sessionNotes = sessionNotes
        self.startedAt = startedAt
        self.scheduledEndAt = scheduledEndAt
        self.endedAt = endedAt
        self.status = status
        self.specialInstructions = specialInstructions
    }
}
