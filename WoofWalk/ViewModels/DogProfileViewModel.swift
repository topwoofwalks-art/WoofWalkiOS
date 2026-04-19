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
        let dogId = editingDog?.id ?? UUID().uuidString

        isLoading = true
        defer { isLoading = false }

        do {
            // EXIF strip + resize + JPEG re-encode — removes any GPS tags
            // embedded by the camera before the bytes leave the device.
            let sanitized = try ImageSanitizer.prepareForUpload(
                imageData: imageData,
                target: .dogPrimary
            )

            // Deterministic filename so updates overwrite the prior object
            // rather than accumulating orphans.
            let path = "dogProfiles/\(userId)/\(dogId).jpg"
            let downloadURL = try await FirebaseService.shared.uploadImage(
                data: sanitized,
                path: path,
                uploadedBy: userId,
                extraMetadata: ["dogId": dogId]
            )
            self.photoUrl = downloadURL.absoluteString
        } catch {
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            throw error
        }
    }

    /// Upload a gallery photo (in addition to the primary). Returns the
    /// gallery photoId + download URL — callers persist the URL in the
    /// dog's `photoUrls` array.
    func uploadGalleryPhoto(imageData: Data) async throws -> (photoId: String, url: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "DogProfile", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        guard let dogId = editingDog?.id else {
            throw NSError(domain: "DogProfile", code: -2, userInfo: [NSLocalizedDescriptionKey: "Gallery requires an existing dog"])
        }
        let photoId = UUID().uuidString
        let sanitized = try ImageSanitizer.prepareForUpload(imageData: imageData, target: .dogGallery)

        let path = "dogProfiles/\(userId)/\(dogId)/gallery/\(photoId).jpg"
        let downloadURL = try await FirebaseService.shared.uploadImage(
            data: sanitized,
            path: path,
            uploadedBy: userId,
            extraMetadata: ["dogId": dogId, "photoId": photoId]
        )
        return (photoId: photoId, url: downloadURL.absoluteString)
    }
}
