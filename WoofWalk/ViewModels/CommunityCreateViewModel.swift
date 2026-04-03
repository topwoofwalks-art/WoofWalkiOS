import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
class CommunityCreateViewModel: ObservableObject {
    // MARK: - Form Fields

    @Published var name: String = ""
    @Published var description: String = ""
    @Published var selectedType: CommunityType = .GENERAL
    @Published var privacy: CommunityPrivacy = .PUBLIC
    @Published var coverImage: UIImage?
    @Published var rules: String = ""
    @Published var tags: [String] = []
    @Published var breedFilter: String = ""
    @Published var location: String = ""

    // MARK: - Wizard State

    @Published var currentStep: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCreated = false

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()

    /// Total number of steps: 0=type, 1=name+desc, 2=rules+privacy, 3=cover+tags, 4=type-specific
    private let totalSteps = 5

    // MARK: - Step Navigation

    func nextStep() {
        guard validateCurrentStep() else { return }

        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            createCommunity()
        }
    }

    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    // MARK: - Validation

    @discardableResult
    func validateCurrentStep() -> Bool {
        errorMessage = nil

        switch currentStep {
        case 0:
            // Type selection - always valid since there's a default
            return true
        case 1:
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            if trimmedName.isEmpty {
                errorMessage = "Community name is required"
                return false
            }
            if trimmedName.count < 3 {
                errorMessage = "Community name must be at least 3 characters"
                return false
            }
            if trimmedName.count > 50 {
                errorMessage = "Community name must be 50 characters or fewer"
                return false
            }
            let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
            if trimmedDesc.isEmpty {
                errorMessage = "Description is required"
                return false
            }
            if trimmedDesc.count < 10 {
                errorMessage = "Description must be at least 10 characters"
                return false
            }
            return true
        case 2:
            // Rules and privacy - privacy has a default, rules are optional
            return true
        case 3:
            // Cover photo and tags - all optional
            return true
        case 4:
            // Type-specific configuration
            if selectedType == .BREED_SPECIFIC && breedFilter.trimmingCharacters(in: .whitespaces).isEmpty {
                errorMessage = "Breed filter is required for breed-specific communities"
                return false
            }
            if selectedType == .LOCAL_NEIGHBOURHOOD && location.trimmingCharacters(in: .whitespaces).isEmpty {
                errorMessage = "Location is required for local neighbourhood communities"
                return false
            }
            return true
        default:
            return true
        }
    }

    // MARK: - Create Community

    func createCommunity() {
        guard let uid = auth.currentUser?.uid else {
            errorMessage = "You must be signed in to create a community"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Get creator name
                let userDoc = try await db.collection("users").document(uid).getDocument()
                let creatorName = userDoc.data()?["username"] as? String ?? "User"

                // Upload cover photo if provided
                var coverPhotoUrl: String?
                if let image = coverImage, let imageData = image.jpegData(compressionQuality: 0.8) {
                    let communityId = UUID().uuidString
                    let fileName = "\(UUID().uuidString).jpg"
                    let storageRef = storage.reference().child("community_covers/\(communityId)/\(fileName)")

                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                    coverPhotoUrl = try await storageRef.downloadURL().absoluteString
                }

                let now = Date().timeIntervalSince1970 * 1000

                let community = Community(
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    type: selectedType.rawValue,
                    privacy: privacy.rawValue,
                    coverPhotoUrl: coverPhotoUrl,
                    createdBy: uid,
                    creatorName: creatorName,
                    memberCount: 1,
                    postCount: 0,
                    rules: rules.trimmingCharacters(in: .whitespaces),
                    tags: tags.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                    breedFilter: selectedType == .BREED_SPECIFIC ? breedFilter.trimmingCharacters(in: .whitespaces) : nil,
                    isVerified: false,
                    isFeatured: false,
                    isArchived: false,
                    createdAt: now,
                    updatedAt: now
                )

                // Create community document
                let docRef = try db.collection("communities").addDocument(from: community)

                // Add creator as OWNER member
                let ownerMember = CommunityMember(
                    userId: uid,
                    communityId: docRef.documentID,
                    displayName: creatorName,
                    photoUrl: userDoc.data()?["photoUrl"] as? String,
                    role: CommunityMemberRole.OWNER.rawValue
                )

                try db.collection("communities").document(docRef.documentID)
                    .collection("members").document(uid).setData(from: ownerMember)

                self.isLoading = false
                self.isCreated = true
                print("[CommunityCreate] Community created: \(docRef.documentID)")
            } catch {
                self.isLoading = false
                self.errorMessage = "Failed to create community: \(error.localizedDescription)"
                print("[CommunityCreate] Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Update Community

    func updateCommunity(communityId: String) {
        guard auth.currentUser?.uid != nil else {
            errorMessage = "You must be signed in"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                var updates: [String: Any] = [
                    "name": name.trimmingCharacters(in: .whitespaces),
                    "description": description.trimmingCharacters(in: .whitespaces),
                    "type": selectedType.rawValue,
                    "privacy": privacy.rawValue,
                    "rules": rules.trimmingCharacters(in: .whitespaces),
                    "tags": tags.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                    "updatedAt": Date().timeIntervalSince1970 * 1000
                ]

                if selectedType == .BREED_SPECIFIC {
                    updates["breedFilter"] = breedFilter.trimmingCharacters(in: .whitespaces)
                }

                // Upload new cover photo if changed
                if let image = coverImage, let imageData = image.jpegData(compressionQuality: 0.8) {
                    let fileName = "\(UUID().uuidString).jpg"
                    let storageRef = storage.reference().child("community_covers/\(communityId)/\(fileName)")

                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                    let url = try await storageRef.downloadURL()
                    updates["coverPhotoUrl"] = url.absoluteString
                }

                try await db.collection("communities").document(communityId).updateData(updates)

                self.isLoading = false
                print("[CommunityCreate] Community updated: \(communityId)")
            } catch {
                self.isLoading = false
                self.errorMessage = "Failed to update community: \(error.localizedDescription)"
                print("[CommunityCreate] Update error: \(error.localizedDescription)")
            }
        }
    }
}
