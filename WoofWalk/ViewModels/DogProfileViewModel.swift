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

    private let userRepository: UserRepository
    private var editingDog: DogProfile?

    let temperaments = ["Friendly", "Shy", "Energetic", "Calm", "Playful", "Protective"]

    init(dog: DogProfile? = nil, userRepository: UserRepository = UserRepository()) {
        self.userRepository = userRepository
        self.editingDog = dog

        if let dog = dog {
            self.name = dog.name
            self.breed = dog.breed
            self.age = "\(dog.age)"
            self.temperament = dog.temperament
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
            let dogProfile = DogProfile(
                id: editingDog?.id ?? UUID().uuidString,
                name: name,
                breed: breed.isEmpty ? "Mixed" : breed,
                age: Int(age) ?? 0,
                photoUrl: photoUrl,
                temperament: temperament,
                nervousDog: nervousDog,
                warningNote: warningNote.isEmpty ? nil : warningNote
            )

            if editingDog != nil {
                try await userRepository.updateDogProfile(dogId: dogProfile.id, dog: dogProfile)
            } else {
                try await userRepository.addDogProfile(dog: dogProfile)
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
            try await userRepository.removeDogProfile(dogId: dogId)
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
            let firebaseService = FirebaseService()
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
