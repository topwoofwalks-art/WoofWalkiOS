import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var email: String
    var photoUrl: String?
    var pawPoints: Int
    var level: Int
    var badges: [String]
    var dogs: [DogProfile]
    @ServerTimestamp var createdAt: Timestamp?
    var regionCode: String
    var totalWalks: Int
    var totalDistanceMeters: Double
    var bio: String
    var displayName: String?
    var role: String?
    var fcmToken: String?
    @ServerTimestamp var updatedAt: Timestamp?
    var marketingOptIn: Bool
    var walkStreak: WalkStreak?
    var leagueTier: String?
    var leagueGroupId: String?
    var leagueWeekId: String?
    var searchableUsername: String
    var searchableEmail: String
    var searchableDisplayName: String

    init(id: String? = nil,
         username: String = "",
         email: String = "",
         photoUrl: String? = nil,
         pawPoints: Int = 0,
         level: Int = 1,
         badges: [String] = [],
         dogs: [DogProfile] = [],
         createdAt: Timestamp? = nil,
         regionCode: String = "",
         totalWalks: Int = 0,
         totalDistanceMeters: Double = 0.0,
         bio: String = "",
         displayName: String? = nil,
         role: String? = nil,
         fcmToken: String? = nil,
         updatedAt: Timestamp? = nil,
         marketingOptIn: Bool = false,
         walkStreak: WalkStreak? = nil,
         leagueTier: String? = nil,
         leagueGroupId: String? = nil,
         leagueWeekId: String? = nil,
         searchableUsername: String = "",
         searchableEmail: String = "",
         searchableDisplayName: String = "") {
        self.id = id
        self.username = username
        self.email = email
        self.photoUrl = photoUrl
        self.pawPoints = pawPoints
        self.level = level
        self.badges = badges
        self.dogs = dogs
        self.createdAt = createdAt
        self.regionCode = regionCode
        self.totalWalks = totalWalks
        self.totalDistanceMeters = totalDistanceMeters
        self.bio = bio
        self.displayName = displayName
        self.role = role
        self.fcmToken = fcmToken
        self.updatedAt = updatedAt
        self.marketingOptIn = marketingOptIn
        self.walkStreak = walkStreak
        self.leagueTier = leagueTier
        self.leagueGroupId = leagueGroupId
        self.leagueWeekId = leagueWeekId
        self.searchableUsername = searchableUsername
        self.searchableEmail = searchableEmail
        self.searchableDisplayName = searchableDisplayName
    }
}

struct DogProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var breed: String
    var age: Int
    var photoUrl: String?
    var temperament: String
    var nervousDog: Bool
    var warningNote: String?
    var birthdate: String?
    var sex: String?
    var neutered: Bool?
    var color: String?
    var weight: Double?
    var size: String?
    var microchipId: String?
    var behavioralNotes: String?
    var selectedGroomerId: String?
    var allergies: String?
    var medications: String?
    var medicalConditions: String?
    var specialNeeds: String?
    var dietaryRestrictions: String?
    var medicationSchedules: [MedicationScheduleEntry]
    var vetDetails: VetDetails?

    init(id: String = UUID().uuidString,
         name: String = "",
         breed: String = "",
         age: Int = 0,
         photoUrl: String? = nil,
         temperament: String = "",
         nervousDog: Bool = false,
         warningNote: String? = nil,
         birthdate: String? = nil,
         sex: String? = nil,
         neutered: Bool? = nil,
         color: String? = nil,
         weight: Double? = nil,
         size: String? = nil,
         microchipId: String? = nil,
         behavioralNotes: String? = nil,
         selectedGroomerId: String? = nil,
         allergies: String? = nil,
         medications: String? = nil,
         medicalConditions: String? = nil,
         specialNeeds: String? = nil,
         dietaryRestrictions: String? = nil,
         medicationSchedules: [MedicationScheduleEntry] = [],
         vetDetails: VetDetails? = nil) {
        self.id = id
        self.name = name
        self.breed = breed
        self.age = age
        self.photoUrl = photoUrl
        self.temperament = temperament
        self.nervousDog = nervousDog
        self.warningNote = warningNote
        self.birthdate = birthdate
        self.sex = sex
        self.neutered = neutered
        self.color = color
        self.weight = weight
        self.size = size
        self.microchipId = microchipId
        self.behavioralNotes = behavioralNotes
        self.selectedGroomerId = selectedGroomerId
        self.allergies = allergies
        self.medications = medications
        self.medicalConditions = medicalConditions
        self.specialNeeds = specialNeeds
        self.dietaryRestrictions = dietaryRestrictions
        self.medicationSchedules = medicationSchedules
        self.vetDetails = vetDetails
    }
}
