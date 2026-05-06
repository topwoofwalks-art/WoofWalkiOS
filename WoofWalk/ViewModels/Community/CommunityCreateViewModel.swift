import Foundation
import FirebaseFirestore
import Combine

/// Steps of the community-create wizard. Matches Android's
/// `CreateCommunityStep` ordering — except iOS surfaces 4 distinct steps
/// (type → basics → privacy → typeSpecific) per the brief, vs Android's
/// BASICS/DETAILS/RULES/REVIEW. Either order works against the same
/// backend write at the end.
enum CreateCommunityStep: Int, CaseIterable {
    case type
    case basics
    case privacy
    case typeSpecific
    case review

    var stepNumber: Int { rawValue + 1 }
    var totalSteps: Int { Self.allCases.count }

    var title: String {
        switch self {
        case .type: return "Type"
        case .basics: return "Basics"
        case .privacy: return "Privacy"
        case .typeSpecific: return "Details"
        case .review: return "Review"
        }
    }
}

@MainActor
final class CommunityCreateViewModel: ObservableObject {
    // Form state
    @Published var step: CreateCommunityStep = .type

    @Published var name: String = ""
    @Published var description: String = ""
    @Published var rules: String = ""
    @Published var tags: [String] = []
    @Published var type: CommunityType = .general
    @Published var privacy: CommunityPrivacy = .public

    @Published var coverPhotoData: Data?
    @Published var coverPhotoUrl: String?
    @Published var isUploadingCover: Bool = false

    // Type-specific
    @Published var breedFilter: String?
    @Published var locationLatitude: Double?
    @Published var locationLongitude: Double?
    @Published var locationName: String = ""
    @Published var radiusKm: Double?
    @Published var sports: Set<String> = []
    @Published var focus: Set<String> = []

    // Result
    @Published var isLoading: Bool = false
    @Published var isSuccess: Bool = false
    @Published var createdCommunityId: String?
    @Published var error: String?

    private let repository: CommunityRepository

    init(repository: CommunityRepository = .shared) {
        self.repository = repository
    }

    // MARK: - Step nav

    func nextStep() {
        guard let next = CreateCommunityStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func previousStep() {
        guard let prev = CreateCommunityStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    var canProceedFromCurrentStep: Bool {
        switch step {
        case .type: return true // any type is valid
        case .basics: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .privacy: return true
        case .typeSpecific: return true
        case .review: return true
        }
    }

    // MARK: - Cover photo

    /// Pre-upload a draft cover so the URL is ready for the create call.
    /// Mirrors `CommunityCreateViewModel.uploadCoverPhoto` on Android.
    func setCoverPhoto(imageData: Data) async {
        coverPhotoData = imageData
        isUploadingCover = true
        do {
            let url = try await repository.uploadCoverPhoto(communityId: nil, imageData: imageData)
            coverPhotoUrl = url
        } catch {
            self.error = error.localizedDescription
        }
        isUploadingCover = false
    }

    // MARK: - Create

    /// Build the community payload from wizard state and write it. Sets
    /// `isSuccess + createdCommunityId` on success so the screen can dismiss
    /// and navigate to the new community.
    func createCommunity() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty {
            error = "Community name is required"
            return
        }
        isLoading = true
        var community = Community(
            name: trimmedName,
            description: description,
            type: type,
            privacy: privacy,
            coverPhotoUrl: coverPhotoUrl,
            rules: rules,
            tags: tags,
            radiusKm: radiusKm,
            breedFilter: breedFilter
        )
        if let lat = locationLatitude, let lon = locationLongitude {
            community.location = GeoPoint(latitude: lat, longitude: lon)
        }
        // Stash type-specific extras in metadata. The wizard surfaces
        // sports for DOG_SPORTS communities and focus areas for
        // HEALTH_NUTRITION; both end up as metadata keys (joined string)
        // so reads don't need new top-level fields and rules don't change.
        var metadata: [String: String] = [:]
        if !sports.isEmpty { metadata["sports"] = sports.sorted().joined(separator: ",") }
        if !focus.isEmpty { metadata["focus"] = focus.sorted().joined(separator: ",") }
        if !locationName.isEmpty { metadata["locationName"] = locationName }
        if !metadata.isEmpty { community.metadata = metadata }

        do {
            let id = try await repository.createCommunity(community)
            createdCommunityId = id
            isSuccess = true
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func clearError() { error = nil }
}

/// Curated tag pools surfaced by the wizard — kept in one place so the
/// review step + the chip selectors share a single source of truth.
enum CommunityCreateOptions {
    static let sports: [String] = [
        "Agility", "Flyball", "Canicross", "Dock Diving",
        "Obedience", "Rally", "Tracking", "Herding",
        "Lure Coursing", "Disc Dog"
    ]

    static let healthFocus: [String] = [
        "Raw Diet", "Kibble", "Wet Food", "Home Cooked",
        "Allergy", "Senior Care", "Joint Health", "Weight Management",
        "Vet-Approved"
    ]

    static let popularBreeds: [String] = [
        "Labrador Retriever", "Cocker Spaniel", "Border Collie",
        "Cockapoo", "Staffordshire Bull Terrier", "Golden Retriever",
        "French Bulldog", "Dachshund", "Jack Russell", "Beagle",
        "Springer Spaniel", "Pug", "Greyhound", "Whippet", "Mixed Breed"
    ]
}
