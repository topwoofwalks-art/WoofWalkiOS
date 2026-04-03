import Foundation
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class DogProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var breed: String = ""
    @Published var age: String = ""
    @Published var temperament: String = "Friendly"
    @Published var nervousDog: Bool = false
    @Published var warningNote: String = ""
    @Published var photoUrl: String?

    @Published var nameError: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dogRepository: DogRepository
    private var editingDog: UnifiedDog?

    let temperaments = ["Friendly", "Shy", "Energetic", "Calm", "Playful", "Protective"]

    init(dog: UnifiedDog? = nil, dogRepository: DogRepository = DogRepository()) {
        self.dogRepository = dogRepository
        self.editingDog = dog

        if let dog = dog {
            self.name = dog.name
            self.breed = dog.breed ?? ""
            self.age = "\(dog.ageYears)"
            self.temperament = dog.temperament ?? "Friendly"
            self.nervousDog = dog.nervousDog
            self.warningNote = dog.warningNote ?? ""
            self.photoUrl = dog.photoUrl
        }
    }

    func validate() -> Bool {
        nameError = nil

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            nameError = "Name is required"
            return false
        }

        return true
    }

    func saveDog() async throws {
        guard validate() else { return }

        isLoading = true
        errorMessage = nil

        do {
            let dog = UnifiedDog(
                id: editingDog?.id ?? UUID().uuidString,
                name: name,
                breed: breed.isEmpty ? "Mixed" : breed,
                photoUrl: photoUrl,
                temperament: temperament,
                nervousDog: nervousDog,
                warningNote: warningNote.isEmpty ? nil : warningNote
            )

            if editingDog != nil {
                try await dogRepository.updateDog(dogId: dog.id!, dog: dog)
            } else {
                try await dogRepository.addDog(dog)
            }

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func deleteDog() async throws {
        guard let dogId = editingDog?.id else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await dogRepository.removeDog(dogId: dogId)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func uploadPhoto(imageData: Data) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DogProfile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        isLoading = true
        do {
            let path = "dogProfiles/\(userId)/\(UUID().uuidString).jpg"
            let firebaseService = FirebaseService.shared
            let downloadURL = try await firebaseService.uploadImage(data: imageData, path: path)
            self.photoUrl = downloadURL.absoluteString
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            throw error
        }
    }
}
