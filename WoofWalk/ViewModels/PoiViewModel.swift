import Foundation
import SwiftUI
import Combine
import CoreLocation
import PhotosUI
import FirebaseAuth
import FirebaseStorage

@MainActor
class PoiViewModel: ObservableObject {
    @Published var selectedType: PoiType = .bin
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var selectedImage: UIImage?
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var showingCamera: Bool = false
    @Published var uploadProgress: Double?
    @Published var error: String?
    @Published var isLoading: Bool = false
    @Published var success: Bool = false

    private let location: CLLocationCoordinate2D
    private let repository = PoiServiceRepository.shared

    init(location: CLLocationCoordinate2D) {
        self.location = location

        Task {
            await loadSelectedPhoto()
        }
    }

    func createPoi() async {
        guard !title.isEmpty else {
            error = "Title is required"
            return
        }

        isLoading = true
        error = nil

        do {
            var photoUrl: String?

            if let image = selectedImage {
                photoUrl = try await uploadPhoto(image)
            }

            let poi = POI(
                type: selectedType.rawValue,
                title: title,
                desc: description,
                lat: location.latitude,
                lng: location.longitude,
                photoUrls: photoUrl != nil ? [photoUrl!] : []
            )

            _ = try await repository.createPoi(poi)

            success = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func uploadPhoto(_ image: UIImage) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PoiViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let imageData: Data
        do {
            imageData = try ImageSanitizer.prepareForUpload(image: image, target: .poi)
        } catch {
            throw NSError(domain: "PoiViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image: \(error.localizedDescription)"])
        }

        let storage = Storage.storage()
        let storageRef = storage.reference()
        let photoRef = storageRef.child("poi_photos/\(UUID().uuidString).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["uploadedBy": uid]

        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = photoRef.putData(imageData, metadata: metadata)

            uploadTask.observe(.progress) { [weak self] snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    self?.uploadProgress = percentComplete
                }
            }

            uploadTask.observe(.success) { _ in
                photoRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    }
                }
            }

            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let photoItem = selectedPhotoItem else { return }

        do {
            if let data = try await photoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
            }
        } catch {
            print("Failed to load photo: \(error)")
        }
    }
}

@MainActor
class PoiDetailViewModel: ObservableObject {
    @Published var comments: [PoiComment] = []
    @Published var commentText: String = ""
    @Published var showingReportSheet: Bool = false
    @Published var showingError: Bool = false
    @Published var error: String?

    private let poi: POI
    private let repository = PoiServiceRepository.shared
    private var cancellables = Set<AnyCancellable>()

    init(poi: POI) {
        self.poi = poi
        loadComments()
    }

    private func loadComments() {
        repository.getComments(poiId: poi.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Failed to load comments: \(error)")
                }
            } receiveValue: { [weak self] comments in
                self?.comments = comments
            }
            .store(in: &cancellables)
    }

    func addComment() async {
        guard !commentText.isEmpty else { return }

        do {
            _ = try await repository.addComment(poiId: poi.id, text: commentText)
            commentText = ""
        } catch {
            self.error = error.localizedDescription
            showingError = true
        }
    }

    func votePoi(upvote: Bool) async {
        do {
            try await repository.votePoi(poiId: poi.id, upvote: upvote)
        } catch {
            self.error = error.localizedDescription
            showingError = true
        }
    }

    func reportPoi(reason: String) async {
        do {
            try await repository.reportPoi(poiId: poi.id, reason: reason)
        } catch {
            self.error = error.localizedDescription
            showingError = true
        }
    }

    func reportPoiMissing() async {
        do {
            try await repository.reportPoiMissing(poiId: poi.id)
        } catch {
            self.error = error.localizedDescription
            showingError = true
        }
    }
}

import Combine
