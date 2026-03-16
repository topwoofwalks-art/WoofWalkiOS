import SwiftData
import Foundation

@Model
final class DogEntity {
    @Attribute(.unique) var dogId: String
    var ownerUid: String?
    var name: String
    var breed: String?
    var birthdateEpochDays: Int?
    var sex: String?
    var color: String?
    var photoUrl: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var nervousDog: Bool
    var warningNote: String?
    var weight: Double?
    var size: String?
    var microchipId: String?
    var temperament: String?
    var behavioralNotes: String?
    var selectedGroomerId: String?
    var allergies: String?
    var medications: String?
    var medicalConditions: String?
    var specialNeeds: String?
    var dietaryRestrictions: String?
    var medicationSchedulesJson: String
    var vetDetailsJson: String?
    var photoUrls: String
    var neutered: Bool
    var gender: String?

    init(
        dogId: String,
        ownerUid: String? = nil,
        name: String,
        breed: String? = nil,
        birthdateEpochDays: Int? = nil,
        sex: String? = nil,
        color: String? = nil,
        photoUrl: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        nervousDog: Bool = false,
        warningNote: String? = nil,
        weight: Double? = nil,
        size: String? = nil,
        microchipId: String? = nil,
        temperament: String? = nil,
        behavioralNotes: String? = nil,
        selectedGroomerId: String? = nil,
        allergies: String? = nil,
        medications: String? = nil,
        medicalConditions: String? = nil,
        specialNeeds: String? = nil,
        dietaryRestrictions: String? = nil,
        medicationSchedulesJson: String = "[]",
        vetDetailsJson: String? = nil,
        photoUrls: String = "[]",
        neutered: Bool = false,
        gender: String? = nil
    ) {
        self.dogId = dogId
        self.ownerUid = ownerUid
        self.name = name
        self.breed = breed
        self.birthdateEpochDays = birthdateEpochDays
        self.sex = sex
        self.color = color
        self.photoUrl = photoUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.nervousDog = nervousDog
        self.warningNote = warningNote
        self.weight = weight
        self.size = size
        self.microchipId = microchipId
        self.temperament = temperament
        self.behavioralNotes = behavioralNotes
        self.selectedGroomerId = selectedGroomerId
        self.allergies = allergies
        self.medications = medications
        self.medicalConditions = medicalConditions
        self.specialNeeds = specialNeeds
        self.dietaryRestrictions = dietaryRestrictions
        self.medicationSchedulesJson = medicationSchedulesJson
        self.vetDetailsJson = vetDetailsJson
        self.photoUrls = photoUrls
        self.neutered = neutered
        self.gender = gender
    }

    func toDomain() -> DogProfile {
        let age: Int
        if let epochDays = birthdateEpochDays {
            let birthdate = Date(timeIntervalSince1970: TimeInterval(epochDays * 86400))
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year], from: birthdate, to: Date())
            age = components.year ?? 0
        } else {
            age = 0
        }

        let decoder = JSONDecoder()
        let decodedPhotoUrls = (try? decoder.decode([String].self, from: photoUrls.data(using: .utf8) ?? Data())) ?? []
        let decodedMedSchedules = (try? decoder.decode([MedicationScheduleEntry].self, from: medicationSchedulesJson.data(using: .utf8) ?? Data())) ?? []
        let decodedVetDetails: VetDetails? = vetDetailsJson.flatMap { json in
            try? decoder.decode(VetDetails.self, from: json.data(using: .utf8) ?? Data())
        }

        return DogProfile(
            id: dogId,
            name: name,
            breed: breed ?? "Mixed",
            age: age,
            photoUrl: photoUrl,
            temperament: temperament ?? "Friendly",
            nervousDog: nervousDog,
            warningNote: warningNote,
            weight: weight,
            size: size,
            microchipId: microchipId,
            behavioralNotes: behavioralNotes,
            selectedGroomerId: selectedGroomerId,
            allergies: allergies,
            medications: medications,
            medicalConditions: medicalConditions,
            specialNeeds: specialNeeds,
            dietaryRestrictions: dietaryRestrictions,
            medicationSchedules: decodedMedSchedules,
            vetDetails: decodedVetDetails,
            photoUrls: decodedPhotoUrls,
            neutered: neutered,
            gender: gender
        )
    }
}
