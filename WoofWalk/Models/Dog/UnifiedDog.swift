import Foundation
import FirebaseFirestore

struct UnifiedDog: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var primaryOwnerId: String
    var sharedWithUserIds: [String]
    var organizationAccess: [OrgAccess]

    // Basic Info
    var breed: String?
    var birthdate: Int64?
    var sex: String?
    var color: String?
    var photoUrl: String?
    var photoUrls: [String]

    // Physical
    var weight: Double?
    var weightHistory: [WeightLog]
    var size: String?
    var microchipId: String?

    // Behavior
    var temperament: String?
    var nervousDog: Bool
    var behavioralNotes: String?
    var warningNote: String?
    var trainingLevel: String?
    var goodWithKids: Bool?
    var goodWithDogs: Bool?
    var goodWithCats: Bool?

    // Medical
    var vetInfo: DogVetInfo?
    // Structured vaccinations live in the
    // `/dogs/{dogId}/medicalRecords` subcollection (type = .vaccination).
    // Firestore rules reject inline medical arrays on the main doc, so
    // the inline field has been dropped in favour of `MedicalRecordsRepository`.
    var vaccinationStatus: String?
    var allergies: String?
    var medications: String?
    var medicationUpToDate: Bool
    var medicalConditions: String?
    var specialNeeds: String?
    var dietaryRestrictions: String?

    // Service Prefs
    var selectedGroomerId: String?
    var selectedWalkerId: String?
    var selectedVetId: String?
    var serviceNotes: String?
    var activityLevel: String?
    var walkPreferences: WalkPreferences?

    // Metadata
    var createdAt: Int64
    var updatedAt: Int64
    var isArchived: Bool
    var archivedAt: Int64?
    var archivedBy: String?
    var version: Int
    var lastSyncedAt: Int64?
    var syncStatus: String
    var species: String?
    var gender: String?
    var neutered: Bool

    /// Age in years computed from birthdate (epoch ms). Returns 0 if no birthdate.
    var ageYears: Int {
        guard let bd = birthdate else { return 0 }
        let birthDate = Date(timeIntervalSince1970: TimeInterval(bd) / 1000.0)
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    init(id: String? = nil, name: String = "", primaryOwnerId: String = "", sharedWithUserIds: [String] = [], organizationAccess: [OrgAccess] = [], breed: String? = nil, birthdate: Int64? = nil, sex: String? = nil, color: String? = nil, photoUrl: String? = nil, photoUrls: [String] = [], weight: Double? = nil, weightHistory: [WeightLog] = [], size: String? = nil, microchipId: String? = nil, temperament: String? = nil, nervousDog: Bool = false, behavioralNotes: String? = nil, warningNote: String? = nil, trainingLevel: String? = nil, goodWithKids: Bool? = nil, goodWithDogs: Bool? = nil, goodWithCats: Bool? = nil, vetInfo: DogVetInfo? = nil, vaccinationStatus: String? = nil, allergies: String? = nil, medications: String? = nil, medicationUpToDate: Bool = false, medicalConditions: String? = nil, specialNeeds: String? = nil, dietaryRestrictions: String? = nil, selectedGroomerId: String? = nil, selectedWalkerId: String? = nil, selectedVetId: String? = nil, serviceNotes: String? = nil, activityLevel: String? = nil, walkPreferences: WalkPreferences? = nil, createdAt: Int64 = 0, updatedAt: Int64 = 0, isArchived: Bool = false, archivedAt: Int64? = nil, archivedBy: String? = nil, version: Int = 1, lastSyncedAt: Int64? = nil, syncStatus: String = "synced", species: String? = nil, gender: String? = nil, neutered: Bool = false) {
        self.id = id; self.name = name; self.primaryOwnerId = primaryOwnerId; self.sharedWithUserIds = sharedWithUserIds; self.organizationAccess = organizationAccess; self.breed = breed; self.birthdate = birthdate; self.sex = sex; self.color = color; self.photoUrl = photoUrl; self.photoUrls = photoUrls; self.weight = weight; self.weightHistory = weightHistory; self.size = size; self.microchipId = microchipId; self.temperament = temperament; self.nervousDog = nervousDog; self.behavioralNotes = behavioralNotes; self.warningNote = warningNote; self.trainingLevel = trainingLevel; self.goodWithKids = goodWithKids; self.goodWithDogs = goodWithDogs; self.goodWithCats = goodWithCats; self.vetInfo = vetInfo; self.vaccinationStatus = vaccinationStatus; self.allergies = allergies; self.medications = medications; self.medicationUpToDate = medicationUpToDate; self.medicalConditions = medicalConditions; self.specialNeeds = specialNeeds; self.dietaryRestrictions = dietaryRestrictions; self.selectedGroomerId = selectedGroomerId; self.selectedWalkerId = selectedWalkerId; self.selectedVetId = selectedVetId; self.serviceNotes = serviceNotes; self.activityLevel = activityLevel; self.walkPreferences = walkPreferences; self.createdAt = createdAt; self.updatedAt = updatedAt; self.isArchived = isArchived; self.archivedAt = archivedAt; self.archivedBy = archivedBy; self.version = version; self.lastSyncedAt = lastSyncedAt; self.syncStatus = syncStatus; self.species = species; self.gender = gender; self.neutered = neutered
    }
}

struct OrgAccess: Codable {
    var orgId: String
    var grantedBy: String
    var grantedAt: Int64
    var permissions: OrgPermissions

    init(orgId: String = "", grantedBy: String = "", grantedAt: Int64 = 0, permissions: OrgPermissions = OrgPermissions()) {
        self.orgId = orgId; self.grantedBy = grantedBy; self.grantedAt = grantedAt; self.permissions = permissions
    }
}

struct OrgPermissions: Codable {
    var canView: Bool
    var canEdit: Bool
    var canBook: Bool
    var canViewMedical: Bool
    var revokedAt: Int64?

    var isRevoked: Bool { revokedAt != nil }

    init(canView: Bool = true, canEdit: Bool = false, canBook: Bool = true, canViewMedical: Bool = false, revokedAt: Int64? = nil) {
        self.canView = canView; self.canEdit = canEdit; self.canBook = canBook; self.canViewMedical = canViewMedical; self.revokedAt = revokedAt
    }
}

struct DogVetInfo: Codable {
    var name: String
    var clinic: String
    var phone: String
    var email: String?
    var address: String?
    var emergencyContact: Bool

    init(name: String = "", clinic: String = "", phone: String = "", email: String? = nil, address: String? = nil, emergencyContact: Bool = false) {
        self.name = name; self.clinic = clinic; self.phone = phone; self.email = email; self.address = address; self.emergencyContact = emergencyContact
    }
}

struct WeightLog: Codable {
    var date: Int64
    var weightKg: Double
    var recordedBy: String?
    var notes: String?

    init(date: Int64 = 0, weightKg: Double = 0, recordedBy: String? = nil, notes: String? = nil) {
        self.date = date; self.weightKg = weightKg; self.recordedBy = recordedBy; self.notes = notes
    }
}

struct WalkPreferences: Codable {
    var preferredDistanceKm: Double?
    var preferredDurationMin: Int?
    var maxDistanceKm: Double?
    var avoidLivestock: Bool
    var preferredTerrain: String?
    var offLeashPreferred: Bool

    init(preferredDistanceKm: Double? = nil, preferredDurationMin: Int? = nil, maxDistanceKm: Double? = nil, avoidLivestock: Bool = false, preferredTerrain: String? = nil, offLeashPreferred: Bool = false) {
        self.preferredDistanceKm = preferredDistanceKm; self.preferredDurationMin = preferredDurationMin; self.maxDistanceKm = maxDistanceKm; self.avoidLivestock = avoidLivestock; self.preferredTerrain = preferredTerrain; self.offLeashPreferred = offLeashPreferred
    }
}

// `DogVaccination` (inline vaccination struct) was removed — vaccinations
// are now stored in the `/dogs/{dogId}/medicalRecords` subcollection and
// read through `MedicalRecordsRepository` as `MedicalRecord` values.

struct DogInvite: Identifiable, Codable {
    @DocumentID var id: String?
    var dogId: String
    var dogName: String
    var invitedBy: String
    var invitedByName: String
    var invitedUserId: String?
    var inviteCode: String
    var status: String // "pending", "accepted"
    var createdAt: Int64
    var acceptedAt: Int64?
    var expiresAt: Int64?

    init(id: String? = nil, dogId: String = "", dogName: String = "", invitedBy: String = "", invitedByName: String = "", invitedUserId: String? = nil, inviteCode: String = "", status: String = "pending", createdAt: Int64 = 0, acceptedAt: Int64? = nil, expiresAt: Int64? = nil) {
        self.id = id; self.dogId = dogId; self.dogName = dogName; self.invitedBy = invitedBy; self.invitedByName = invitedByName; self.invitedUserId = invitedUserId; self.inviteCode = inviteCode; self.status = status; self.createdAt = createdAt; self.acceptedAt = acceptedAt; self.expiresAt = expiresAt
    }
}
