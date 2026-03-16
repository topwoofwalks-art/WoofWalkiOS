import SwiftUI

@MainActor
class UnifiedDogFormViewModel: ObservableObject {
    // Basic
    @Published var name = ""
    @Published var breed = ""
    @Published var birthdate: Date?
    @Published var sex = ""
    @Published var neutered = false
    @Published var color = ""

    // Physical
    @Published var size = ""
    @Published var weight: Double?
    @Published var microchipId = ""

    // Behavior
    @Published var temperament = "Friendly"
    @Published var nervousDog = false
    @Published var warningNote = ""
    @Published var behavioralNotes = ""

    // Medical
    @Published var allergies = ""
    @Published var medicalConditions = ""
    @Published var specialNeeds = ""
    @Published var dietaryRestrictions = ""
    @Published var medicationSchedules: [MedicationScheduleEntry] = []

    // Vet
    @Published var vetPracticeName = ""
    @Published var vetName = ""
    @Published var vetPhone = ""
    @Published var vetAddress = ""

    private var existingId: String?

    init(dog: DogProfile? = nil) {
        if let dog = dog {
            existingId = dog.id
            name = dog.name
            breed = dog.breed
            sex = dog.sex ?? ""
            neutered = dog.neutered ?? false
            color = dog.color ?? ""
            size = dog.size ?? ""
            weight = dog.weight
            microchipId = dog.microchipId ?? ""
            temperament = dog.temperament
            nervousDog = dog.nervousDog
            warningNote = dog.warningNote ?? ""
            behavioralNotes = dog.behavioralNotes ?? ""
            allergies = dog.allergies ?? ""
            medicalConditions = dog.medicalConditions ?? ""
            specialNeeds = dog.specialNeeds ?? ""
            dietaryRestrictions = dog.dietaryRestrictions ?? ""
            medicationSchedules = dog.medicationSchedules

            if let vet = dog.vetDetails {
                vetPracticeName = vet.practiceName
                vetName = vet.vetName
                vetPhone = vet.phone
                vetAddress = vet.address
            }

            if let birthdateStr = dog.birthdate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                birthdate = formatter.date(from: birthdateStr)
            }
        }
    }

    func addMedication() {
        medicationSchedules.append(MedicationScheduleEntry())
    }

    func toDogProfile() -> DogProfile {
        let birthdateStr: String? = birthdate.map {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: $0)
        }

        let vet: VetDetails? = vetPracticeName.isEmpty && vetName.isEmpty ? nil : VetDetails(
            practiceName: vetPracticeName,
            vetName: vetName,
            phone: vetPhone,
            address: vetAddress
        )

        return DogProfile(
            id: existingId ?? UUID().uuidString,
            name: name,
            breed: breed,
            age: birthdate.map { Calendar.current.dateComponents([.year], from: $0, to: Date()).year ?? 0 } ?? 0,
            temperament: temperament,
            nervousDog: nervousDog,
            warningNote: warningNote.isEmpty ? nil : warningNote,
            birthdate: birthdateStr,
            sex: sex.isEmpty ? nil : sex,
            neutered: neutered,
            color: color.isEmpty ? nil : color,
            weight: weight,
            size: size.isEmpty ? nil : size,
            microchipId: microchipId.isEmpty ? nil : microchipId,
            behavioralNotes: behavioralNotes.isEmpty ? nil : behavioralNotes,
            allergies: allergies.isEmpty ? nil : allergies,
            medicalConditions: medicalConditions.isEmpty ? nil : medicalConditions,
            specialNeeds: specialNeeds.isEmpty ? nil : specialNeeds,
            dietaryRestrictions: dietaryRestrictions.isEmpty ? nil : dietaryRestrictions,
            medicationSchedules: medicationSchedules,
            vetDetails: vet
        )
    }
}
