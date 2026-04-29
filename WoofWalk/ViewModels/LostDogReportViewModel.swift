import Foundation
import SwiftUI
import CoreLocation
import FirebaseAuth

@MainActor
final class LostDogReportViewModel: ObservableObject {

    // ── Form state ─────────────────────────────────────────────────
    @Published var dogName: String = ""
    @Published var dogBreed: String = ""
    @Published var description: String = ""
    @Published var locationDescription: String = ""
    @Published var reporterPhone: String = ""
    @Published var durationHours: Int = 24
    @Published var alertRadiusKm: Double = 5

    // Captured location (filled from LocationService on appear).
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var locationError: String?
    @Published var isFetchingLocation: Bool = false

    // Photo
    @Published var selectedImageData: Data?
    @Published var uploadProgress: Double = 0  // 0...1, advisory only
    @Published var uploadedPhotoUrl: String?

    // Submission
    @Published var isSubmitting: Bool = false
    @Published var submitError: String?
    @Published var submitSuccess: Bool = false
    @Published var newAlertId: String?

    // Optional: pre-fill from the user's own dog when they tap "report
    // my dog as lost" from the dog detail screen. Empty string means
    // "I found a stray" — same convention as Android.
    var prefillDogId: String = ""

    private let repository = LostDogRepository.shared
    private let location = LocationService.shared

    // MARK: - Location capture

    /// Pulls a fresh GPS fix and writes it to `coordinate`. Called on
    /// screen appear; user can also tap "Use current location" to
    /// retry if the first fix was rejected (e.g. permission only just
    /// granted).
    func captureLocation() async {
        isFetchingLocation = true
        locationError = nil
        defer { isFetchingLocation = false }
        do {
            // 10s timeout matches the LocationService default. Using
            // its async wrapper keeps the @MainActor contract.
            let coord = try await location.getCurrentLocation(timeout: 10.0)
            coordinate = coord
        } catch {
            locationError = "Could not get a location fix. Tap 'Use current location' to retry, or enable Location Services in Settings."
        }
    }

    // MARK: - Validation

    var canSubmit: Bool {
        !dogName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !dogBreed.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        coordinate != nil &&
        !isSubmitting
    }

    // MARK: - Submit

    func submit() async {
        guard canSubmit, let coord = coordinate else { return }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        do {
            // Upload photo first if one was attached. Failure here
            // is non-fatal — the alert can still go out without a
            // photo and the user can re-attach later.
            var photoUrl: String? = uploadedPhotoUrl
            if photoUrl == nil, let data = selectedImageData {
                do {
                    photoUrl = try await repository.uploadPhoto(data)
                    uploadedPhotoUrl = photoUrl
                } catch {
                    print("[LostDogReport] photo upload failed: \(error)")
                    // Carry on; better to have a no-photo alert than no alert.
                }
            }

            let id = try await repository.reportLostDog(
                dogId: prefillDogId,
                dogName: dogName.trimmingCharacters(in: .whitespaces),
                dogPhotoUrl: photoUrl,
                dogBreed: dogBreed.trimmingCharacters(in: .whitespaces),
                lat: coord.latitude,
                lng: coord.longitude,
                locationDescription: locationDescription.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                reporterPhone: reporterPhone.trimmingCharacters(in: .whitespaces).isEmpty
                    ? nil
                    : reporterPhone.trimmingCharacters(in: .whitespaces),
                durationHours: durationHours,
                alertRadiusKm: alertRadiusKm
            )
            newAlertId = id
            submitSuccess = true
        } catch {
            submitError = error.localizedDescription
        }
    }
}
