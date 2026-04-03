import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Community Type

enum CommunityType: String, Codable, CaseIterable {
    case BREED_SPECIFIC
    case LOCAL_NEIGHBOURHOOD
    case TRAINING_BEHAVIOUR
    case RESCUE_REHOMING
    case PUPPY_PARENTS
    case SENIOR_DOGS
    case DOG_SPORTS
    case DOG_FRIENDLY_TRAVEL
    case HEALTH_NUTRITION
    case GENERAL

    var displayName: String {
        switch self {
        case .BREED_SPECIFIC: return "Breed Specific"
        case .LOCAL_NEIGHBOURHOOD: return "Local Neighbourhood"
        case .TRAINING_BEHAVIOUR: return "Training & Behaviour"
        case .RESCUE_REHOMING: return "Rescue & Rehoming"
        case .PUPPY_PARENTS: return "Puppy Parents"
        case .SENIOR_DOGS: return "Senior Dogs"
        case .DOG_SPORTS: return "Dog Sports"
        case .DOG_FRIENDLY_TRAVEL: return "Dog-Friendly Travel"
        case .HEALTH_NUTRITION: return "Health & Nutrition"
        case .GENERAL: return "General"
        }
    }

    var iconName: String {
        switch self {
        case .BREED_SPECIFIC: return "pawprint.fill"
        case .LOCAL_NEIGHBOURHOOD: return "mappin.and.ellipse"
        case .TRAINING_BEHAVIOUR: return "graduationcap.fill"
        case .RESCUE_REHOMING: return "heart.circle.fill"
        case .PUPPY_PARENTS: return "star.circle.fill"
        case .SENIOR_DOGS: return "hands.sparkles.fill"
        case .DOG_SPORTS: return "figure.run"
        case .DOG_FRIENDLY_TRAVEL: return "airplane"
        case .HEALTH_NUTRITION: return "cross.case.fill"
        case .GENERAL: return "person.3.fill"
        }
    }

    var description: String {
        switch self {
        case .BREED_SPECIFIC: return "Connect with owners of the same breed"
        case .LOCAL_NEIGHBOURHOOD: return "Meet dog owners in your area"
        case .TRAINING_BEHAVIOUR: return "Share tips and get advice on dog training"
        case .RESCUE_REHOMING: return "Support rescue dogs and find forever homes"
        case .PUPPY_PARENTS: return "First-time and experienced puppy owners"
        case .SENIOR_DOGS: return "Care and community for older dogs"
        case .DOG_SPORTS: return "Agility, flyball, canicross and more"
        case .DOG_FRIENDLY_TRAVEL: return "Discover dog-friendly destinations and tips"
        case .HEALTH_NUTRITION: return "Diet plans, vet advice and wellness tips"
        case .GENERAL: return "A place for all dog lovers"
        }
    }

    var color: Color {
        switch self {
        case .BREED_SPECIFIC: return Color(red: 0.898, green: 0.451, blue: 0.451)
        case .LOCAL_NEIGHBOURHOOD: return Color(red: 0.506, green: 0.780, blue: 0.518)
        case .TRAINING_BEHAVIOUR: return Color(red: 0.392, green: 0.710, blue: 0.965)
        case .RESCUE_REHOMING: return Color(red: 1.0, green: 0.718, blue: 0.302)
        case .PUPPY_PARENTS: return Color(red: 0.941, green: 0.384, blue: 0.573)
        case .SENIOR_DOGS: return Color(red: 0.729, green: 0.408, blue: 0.784)
        case .DOG_SPORTS: return Color(red: 0.310, green: 0.765, blue: 0.969)
        case .DOG_FRIENDLY_TRAVEL: return Color(red: 0.302, green: 0.714, blue: 0.675)
        case .HEALTH_NUTRITION: return Color(red: 0.682, green: 0.835, blue: 0.506)
        case .GENERAL: return Color(red: 0.565, green: 0.643, blue: 0.682)
        }
    }
}

// MARK: - Community Privacy

enum CommunityPrivacy: String, Codable, CaseIterable {
    case PUBLIC
    case PRIVATE
    case INVITE_ONLY
}

// MARK: - Community Member Role

enum CommunityMemberRole: String, Codable, CaseIterable {
    case OWNER
    case ADMIN
    case MODERATOR
    case MEMBER

    func canModerate() -> Bool {
        return self == .OWNER || self == .ADMIN || self == .MODERATOR
    }

    func canAdmin() -> Bool {
        return self == .OWNER || self == .ADMIN
    }

    func isOwner() -> Bool {
        return self == .OWNER
    }
}

// MARK: - Community

/// Firestore path: communities/{communityId}
struct Community: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var type: String
    var privacy: String
    var coverPhotoUrl: String?
    var iconUrl: String?
    var createdBy: String
    var creatorName: String
    var memberCount: Int
    var postCount: Int
    var rules: String
    var tags: [String]
    var latitude: Double?
    var longitude: Double?
    var geohash: String?
    var radiusKm: Double?
    var breedFilter: String?
    var isVerified: Bool
    var isFeatured: Bool
    var isArchived: Bool
    var metadata: [String: String]?
    var createdAt: Double
    var updatedAt: Double

    init(id: String? = nil,
         name: String = "",
         description: String = "",
         type: String = CommunityType.GENERAL.rawValue,
         privacy: String = CommunityPrivacy.PUBLIC.rawValue,
         coverPhotoUrl: String? = nil,
         iconUrl: String? = nil,
         createdBy: String = "",
         creatorName: String = "",
         memberCount: Int = 0,
         postCount: Int = 0,
         rules: String = "",
         tags: [String] = [],
         latitude: Double? = nil,
         longitude: Double? = nil,
         geohash: String? = nil,
         radiusKm: Double? = nil,
         breedFilter: String? = nil,
         isVerified: Bool = false,
         isFeatured: Bool = false,
         isArchived: Bool = false,
         metadata: [String: String]? = nil,
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         updatedAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.privacy = privacy
        self.coverPhotoUrl = coverPhotoUrl
        self.iconUrl = iconUrl
        self.createdBy = createdBy
        self.creatorName = creatorName
        self.memberCount = memberCount
        self.postCount = postCount
        self.rules = rules
        self.tags = tags
        self.latitude = latitude
        self.longitude = longitude
        self.geohash = geohash
        self.radiusKm = radiusKm
        self.breedFilter = breedFilter
        self.isVerified = isVerified
        self.isFeatured = isFeatured
        self.isArchived = isArchived
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func getCommunityType() -> CommunityType {
        return CommunityType(rawValue: type) ?? .GENERAL
    }

    func getCommunityPrivacy() -> CommunityPrivacy {
        return CommunityPrivacy(rawValue: privacy) ?? .PUBLIC
    }

    func isLocalCommunity() -> Bool {
        return getCommunityType() == .LOCAL_NEIGHBOURHOOD && latitude != nil
    }

    func isBreedCommunity() -> Bool {
        return getCommunityType() == .BREED_SPECIFIC && breedFilter != nil && !breedFilter!.isEmpty
    }

    func isPublic() -> Bool {
        return getCommunityPrivacy() == .PUBLIC
    }

    func requiresInvite() -> Bool {
        return getCommunityPrivacy() == .INVITE_ONLY
    }
}

// MARK: - Community Member

/// Firestore path: communities/{communityId}/members/{userId}
struct CommunityMember: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var communityId: String
    var displayName: String
    var photoUrl: String?
    var role: String
    var dogNames: [String]
    var dogBreeds: [String]
    var bio: String
    var isMuted: Bool
    var isBanned: Bool
    var banReason: String?
    var notificationsEnabled: Bool
    var postCount: Int
    var commentCount: Int
    var joinedAt: Double
    var lastActiveAt: Double

    init(id: String? = nil,
         userId: String = "",
         communityId: String = "",
         displayName: String = "",
         photoUrl: String? = nil,
         role: String = CommunityMemberRole.MEMBER.rawValue,
         dogNames: [String] = [],
         dogBreeds: [String] = [],
         bio: String = "",
         isMuted: Bool = false,
         isBanned: Bool = false,
         banReason: String? = nil,
         notificationsEnabled: Bool = true,
         postCount: Int = 0,
         commentCount: Int = 0,
         joinedAt: Double = Date().timeIntervalSince1970 * 1000,
         lastActiveAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.userId = userId
        self.communityId = communityId
        self.displayName = displayName
        self.photoUrl = photoUrl
        self.role = role
        self.dogNames = dogNames
        self.dogBreeds = dogBreeds
        self.bio = bio
        self.isMuted = isMuted
        self.isBanned = isBanned
        self.banReason = banReason
        self.notificationsEnabled = notificationsEnabled
        self.postCount = postCount
        self.commentCount = commentCount
        self.joinedAt = joinedAt
        self.lastActiveAt = lastActiveAt
    }

    func getMemberRole() -> CommunityMemberRole {
        return CommunityMemberRole(rawValue: role) ?? .MEMBER
    }

    func canPost() -> Bool {
        return !isMuted && !isBanned
    }

    func canModerate() -> Bool {
        return getMemberRole().canModerate() && !isBanned
    }

    func canAdmin() -> Bool {
        return getMemberRole().canAdmin() && !isBanned
    }

    func isOwner() -> Bool {
        return getMemberRole().isOwner()
    }
}
