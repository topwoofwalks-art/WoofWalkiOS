import SwiftData
import Foundation

@MainActor
class DogRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func upsert(_ dog: DogEntity) throws {
        if let existing = try get(dog.dogId) {
            existing.name = dog.name
            existing.breed = dog.breed
            existing.birthdateEpochDays = dog.birthdateEpochDays
            existing.sex = dog.sex
            existing.color = dog.color
            existing.photoUrl = dog.photoUrl
            existing.updatedAt = dog.updatedAt
            existing.isArchived = dog.isArchived
            existing.nervousDog = dog.nervousDog
            existing.warningNote = dog.warningNote
            existing.weight = dog.weight
            existing.size = dog.size
            existing.microchipId = dog.microchipId
            existing.temperament = dog.temperament
            existing.behavioralNotes = dog.behavioralNotes
            existing.selectedGroomerId = dog.selectedGroomerId
            existing.allergies = dog.allergies
            existing.medications = dog.medications
            existing.medicalConditions = dog.medicalConditions
            existing.specialNeeds = dog.specialNeeds
            existing.dietaryRestrictions = dog.dietaryRestrictions
            existing.medicationSchedulesJson = dog.medicationSchedulesJson
            existing.vetDetailsJson = dog.vetDetailsJson
            existing.photoUrls = dog.photoUrls
            existing.neutered = dog.neutered
            existing.gender = dog.gender
        } else {
            modelContext.insert(dog)
        }
        try modelContext.save()
    }

    func upsertAll(_ dogs: [DogEntity]) throws {
        for dog in dogs {
            try upsert(dog)
        }
    }

    func update(_ dog: DogEntity) throws {
        try modelContext.save()
    }

    func dogsFlow() throws -> [DogEntity] {
        let descriptor = FetchDescriptor<DogEntity>(
            predicate: #Predicate { $0.isArchived == false },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func get(_ id: String) throws -> DogEntity? {
        let descriptor = FetchDescriptor<DogEntity>(
            predicate: #Predicate { $0.dogId == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func getDogFlow(_ id: String) throws -> DogEntity? {
        return try get(id)
    }

    func dogsByOwner(_ ownerUid: String) throws -> [DogEntity] {
        let descriptor = FetchDescriptor<DogEntity>(
            predicate: #Predicate { dog in
                dog.ownerUid == ownerUid && dog.isArchived == false
            }
        )
        return try modelContext.fetch(descriptor)
    }

    func archive(_ id: String, timestamp: Date = Date()) throws {
        if let dog = try get(id) {
            dog.isArchived = true
            dog.updatedAt = timestamp
            try modelContext.save()
        }
    }

    func delete(_ id: String) throws {
        if let dog = try get(id) {
            modelContext.delete(dog)
            try modelContext.save()
        }
    }
}
