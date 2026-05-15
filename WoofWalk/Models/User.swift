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
    /// Denormalised public projection of the user's dogs — maintained
    /// by the onDogWrite Cloud Function from /dogs/{dogId}. Structurally
    /// cannot carry medications, vet, microchip, weight, etc.
    var dogs: [DogProfilePublic]
    @ServerTimestamp var createdAt: Timestamp?
    var regionCode: String
    var totalWalks: Int
    var totalDistanceMeters: Double
    var totalDurationSec: Int
    var poisCreated: Int
    var votesGiven: Int
    var photosUploaded: Int
    var hazardsReported: Int
    var earlyBirdWalks: Int
    var nightOwlWalks: Int
    var uniqueParksVisited: Int
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

    // Contact + delivery details — optional so existing user docs without
    // these fields decode fine. The portal ClientProfile + Android
    // EditProfile let the user fill them in; the geocoding CF derives
    // addressGeo from address.postcode (server-only write).
    var phone: String?
    var phoneVerified: Bool?
    var address: PostalAddress?
    var addressGeo: GeoPoint?

    init(id: String? = nil,
         username: String = "",
         email: String = "",
         photoUrl: String? = nil,
         pawPoints: Int = 0,
         level: Int = 1,
         badges: [String] = [],
         dogs: [DogProfilePublic] = [],
         createdAt: Timestamp? = nil,
         regionCode: String = "",
         totalWalks: Int = 0,
         totalDistanceMeters: Double = 0.0,
         totalDurationSec: Int = 0,
         poisCreated: Int = 0,
         votesGiven: Int = 0,
         photosUploaded: Int = 0,
         hazardsReported: Int = 0,
         earlyBirdWalks: Int = 0,
         nightOwlWalks: Int = 0,
         uniqueParksVisited: Int = 0,
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
         searchableDisplayName: String = "",
         phone: String? = nil,
         phoneVerified: Bool? = nil,
         address: PostalAddress? = nil,
         addressGeo: GeoPoint? = nil) {
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
        self.totalDurationSec = totalDurationSec
        self.poisCreated = poisCreated
        self.votesGiven = votesGiven
        self.photosUploaded = photosUploaded
        self.hazardsReported = hazardsReported
        self.earlyBirdWalks = earlyBirdWalks
        self.nightOwlWalks = nightOwlWalks
        self.uniqueParksVisited = uniqueParksVisited
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
        self.phone = phone
        self.phoneVerified = phoneVerified
        self.address = address
        self.addressGeo = addressGeo
    }
}

/// Postal address attached to a user profile. Optional struct on
/// `users/{uid}.address`. Mirrors Android `PostalAddress` and the
/// portal type `PostalAddress` in ClientProfile.tsx so a doc written by
/// any platform decodes cleanly on the others.
struct PostalAddress: Codable, Equatable {
    var line1: String
    var line2: String
    var city: String
    var postcode: String
    /// ISO 3166-1 alpha-2, e.g. "GB". Defaults to "GB" when blank — the
    /// geocoding CF gates non-GB postcodes off postcodes.io anyway.
    var country: String

    init(line1: String = "", line2: String = "", city: String = "",
         postcode: String = "", country: String = "") {
        self.line1 = line1
        self.line2 = line2
        self.city = city
        self.postcode = postcode
        self.country = country
    }

    var isBlank: Bool {
        line1.isEmpty && city.isEmpty && postcode.isEmpty
    }

    func asSingleLine() -> String {
        [line1, line2, city, postcode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// Full dog profile — the owner's view, with sensitive fields like
/// medications/weight/vet details. `DogProfilePublic` (in
/// Models/DogProfilePublic.swift) is the redacted projection seen
/// by friends. The owner's own ProfileView/EditProfileView reads
/// from `users/{uid}.dogs[]` which is `[DogProfilePublic]` — for
/// the moment we widen via the `from:` initialiser; eventually
/// these screens should fetch full UnifiedDog from DogRepository.
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

    /// Widen a public projection to a full DogProfile. Sensitive
    /// fields (weight, microchip, vet, medications, allergies, etc.)
    /// are unknown from the public projection — they default to nil
    /// here. ProfileView / EditProfileView call this for "my own
    /// dogs" rendering; the proper fix is to fetch full UnifiedDog
    /// from DogRepository for the owner's case, but this widening
    /// keeps the existing screens compiling against the canonical
    /// public model in `users/{uid}.dogs[]`.
    init(from publicDog: DogProfilePublic) {
        self.id = publicDog.id
        self.name = publicDog.name
        self.breed = publicDog.breed ?? ""
        self.age = publicDog.ageYears
        self.photoUrl = publicDog.photoUrl
        self.temperament = publicDog.temperament ?? ""
        self.nervousDog = publicDog.nervousDog
        self.warningNote = publicDog.warningNote
        // birthdate on DogProfile is String (legacy ISO date); the
        // public projection has it as Int64 millis. Convert for
        // display continuity.
        if let bd = publicDog.birthdate {
            let date = Date(timeIntervalSince1970: TimeInterval(bd) / 1000.0)
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            self.birthdate = fmt.string(from: date)
        } else {
            self.birthdate = nil
        }
        self.sex = publicDog.sex
        self.neutered = publicDog.neutered
        self.color = publicDog.color
        self.weight = nil
        self.size = publicDog.size
        self.microchipId = nil
        self.behavioralNotes = publicDog.behavioralNotes
        self.selectedGroomerId = nil
        self.allergies = nil
        self.medications = nil
        self.medicalConditions = nil
        self.specialNeeds = nil
        self.dietaryRestrictions = nil
        self.medicationSchedules = []
        self.vetDetails = nil
    }
}
