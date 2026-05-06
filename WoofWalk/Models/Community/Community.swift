import Foundation
import FirebaseFirestore

// MARK: - CommunityType

/// Mirrors `data.model.community.CommunityType` on Android — the raw value is
/// the enum case name written to Firestore (e.g. "BREED_SPECIFIC"). The
/// shared backend stores `type` as that uppercase string; using the same raw
/// values keeps cross-client reads/writes coherent.
enum CommunityType: String, Codable, CaseIterable, Identifiable {
    case breedSpecific = "BREED_SPECIFIC"
    case localNeighbourhood = "LOCAL_NEIGHBOURHOOD"
    case trainingBehaviour = "TRAINING_BEHAVIOUR"
    case rescueRehoming = "RESCUE_REHOMING"
    case puppyParents = "PUPPY_PARENTS"
    case seniorDogs = "SENIOR_DOGS"
    case dogSports = "DOG_SPORTS"
    case dogFriendlyTravel = "DOG_FRIENDLY_TRAVEL"
    case healthNutrition = "HEALTH_NUTRITION"
    case general = "GENERAL"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breedSpecific: return "Breed Specific"
        case .localNeighbourhood: return "Local Neighbourhood"
        case .trainingBehaviour: return "Training & Behaviour"
        case .rescueRehoming: return "Rescue & Rehoming"
        case .puppyParents: return "Puppy Parents"
        case .seniorDogs: return "Senior Dogs"
        case .dogSports: return "Dog Sports"
        case .dogFriendlyTravel: return "Dog-Friendly Travel"
        case .healthNutrition: return "Health & Nutrition"
        case .general: return "General"
        }
    }

    var description: String {
        switch self {
        case .breedSpecific: return "Connect with owners of the same breed"
        case .localNeighbourhood: return "Meet dog owners in your area"
        case .trainingBehaviour: return "Share tips and get advice on dog training"
        case .rescueRehoming: return "Support rescue dogs and find forever homes"
        case .puppyParents: return "First-time and experienced puppy owners"
        case .seniorDogs: return "Care and community for older dogs"
        case .dogSports: return "Agility, flyball, canicross and more"
        case .dogFriendlyTravel: return "Discover dog-friendly destinations and tips"
        case .healthNutrition: return "Diet plans, vet advice and wellness tips"
        case .general: return "A place for all dog lovers"
        }
    }

    var iconSystemName: String {
        switch self {
        case .breedSpecific: return "pawprint.fill"
        case .localNeighbourhood: return "mappin.and.ellipse"
        case .trainingBehaviour: return "graduationcap.fill"
        case .rescueRehoming: return "heart.fill"
        case .puppyParents: return "figure.and.child.holdinghands"
        case .seniorDogs: return "leaf.fill"
        case .dogSports: return "trophy.fill"
        case .dogFriendlyTravel: return "airplane"
        case .healthNutrition: return "cross.case.fill"
        case .general: return "person.3.fill"
        }
    }

    /// Hex-style colour matching Android's `CommunityType.color` longs.
    var color: (red: Double, green: Double, blue: Double) {
        switch self {
        case .breedSpecific: return (0xE5/255.0, 0x73/255.0, 0x73/255.0)
        case .localNeighbourhood: return (0x81/255.0, 0xC7/255.0, 0x84/255.0)
        case .trainingBehaviour: return (0x64/255.0, 0xB5/255.0, 0xF6/255.0)
        case .rescueRehoming: return (0xFF/255.0, 0xB7/255.0, 0x4D/255.0)
        case .puppyParents: return (0xF0/255.0, 0x62/255.0, 0x92/255.0)
        case .seniorDogs: return (0xBA/255.0, 0x68/255.0, 0xC8/255.0)
        case .dogSports: return (0x4F/255.0, 0xC3/255.0, 0xF7/255.0)
        case .dogFriendlyTravel: return (0x4D/255.0, 0xB6/255.0, 0xAC/255.0)
        case .healthNutrition: return (0xAE/255.0, 0xD5/255.0, 0x81/255.0)
        case .general: return (0x90/255.0, 0xA4/255.0, 0xAE/255.0)
        }
    }

    static func from(_ raw: String?) -> CommunityType {
        guard let raw else { return .general }
        return CommunityType(rawValue: raw.uppercased()) ?? .general
    }
}

// MARK: - CommunityPrivacy

enum CommunityPrivacy: String, Codable, CaseIterable, Identifiable {
    case `public` = "PUBLIC"
    case `private` = "PRIVATE"
    case inviteOnly = "INVITE_ONLY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .public: return "Public"
        case .private: return "Private"
        case .inviteOnly: return "Invite Only"
        }
    }

    var description: String {
        switch self {
        case .public: return "Anyone can find and join"
        case .private: return "Anyone can find, but joining requires approval"
        case .inviteOnly: return "Hidden from search; invite required"
        }
    }

    var iconSystemName: String {
        switch self {
        case .public: return "globe"
        case .private: return "lock"
        case .inviteOnly: return "envelope.badge"
        }
    }

    static func from(_ raw: String?) -> CommunityPrivacy {
        guard let raw else { return .public }
        return CommunityPrivacy(rawValue: raw.uppercased()) ?? .public
    }
}

// MARK: - CommunityMemberRole

enum CommunityMemberRole: String, Codable, CaseIterable {
    case owner = "OWNER"
    case admin = "ADMIN"
    case moderator = "MODERATOR"
    case member = "MEMBER"

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .moderator: return "Moderator"
        case .member: return "Member"
        }
    }

    var sortOrder: Int {
        switch self {
        case .owner: return 0
        case .admin: return 1
        case .moderator: return 2
        case .member: return 3
        }
    }

    var canModerate: Bool {
        self == .owner || self == .admin || self == .moderator
    }

    var canAdmin: Bool {
        self == .owner || self == .admin
    }

    var isOwner: Bool { self == .owner }

    static func from(_ raw: String?) -> CommunityMemberRole {
        guard let raw else { return .member }
        return CommunityMemberRole(rawValue: raw.uppercased()) ?? .member
    }
}

// MARK: - Community

/// A community group on the shared Firestore backend. Path:
/// `communities/{communityId}`. Field names match the Android `Community`
/// data class one-for-one — both clients read & write the same docs.
///
/// `id` is a plain optional (not `@DocumentID`) — see LostDog.swift for the
/// project's preferred approach. Custom `init(from:)` would otherwise
/// bypass `@DocumentID`'s special Decoder mechanism and silently drop the
/// document id during decode. Repository code populates `id` from
/// `doc.documentID` after the throwing `data(as:)` call.
///
/// `createdAt` / `updatedAt` are stored as Long epoch-ms on the wire
/// (Android's source of truth). Older docs were sometimes written as
/// `Timestamp`; the manual `init(from:)` accepts both shapes so a stale
/// cache entry can't crash the entire list (mirrors the Android safe
/// deserializers in CommunityRepository.kt:683+).
struct Community: Identifiable, Codable, Equatable {
    var id: String?
    var name: String = ""
    var description: String = ""
    var type: CommunityType = .general
    var privacy: CommunityPrivacy = .public
    var coverPhotoUrl: String?
    var iconUrl: String?
    var createdBy: String = ""
    var creatorName: String = ""
    var memberCount: Int = 0
    var postCount: Int = 0
    var rules: String = ""
    var tags: [String] = []
    var location: GeoPoint?
    var geohash: String?
    var radiusKm: Double?
    var breedFilter: String?
    var isVerified: Bool = false
    var isFeatured: Bool = false
    var isArchived: Bool = false
    /// Free-form metadata bag. Kept as `[String: String]` because Firestore's
    /// auto-decoder rejects heterogeneous `Any` values; the wizard only
    /// persists string-coerceable values into this map (sports, focus tags).
    var metadata: [String: String]?
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    var updatedAt: Double = Date().timeIntervalSince1970 * 1000

    var isLocalCommunity: Bool { type == .localNeighbourhood && location != nil }
    var isBreedCommunity: Bool { type == .breedSpecific && !(breedFilter?.isEmpty ?? true) }
    var isPublic: Bool { privacy == .public }
    var isPrivate: Bool { privacy == .private }
    var requiresInvite: Bool { privacy == .inviteOnly }

    enum CodingKeys: String, CodingKey {
        case id
        case name, description, type, privacy
        case coverPhotoUrl, iconUrl
        case createdBy, creatorName
        case memberCount, postCount
        case rules, tags
        case location, geohash, radiusKm
        case breedFilter
        case isVerified, isFeatured, isArchived
        case metadata
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        if let typeRaw = try? c.decode(String.self, forKey: .type) {
            self.type = CommunityType.from(typeRaw)
        }
        if let privacyRaw = try? c.decode(String.self, forKey: .privacy) {
            self.privacy = CommunityPrivacy.from(privacyRaw)
        }
        self.coverPhotoUrl = try? c.decode(String.self, forKey: .coverPhotoUrl)
        self.iconUrl = try? c.decode(String.self, forKey: .iconUrl)
        self.createdBy = (try? c.decode(String.self, forKey: .createdBy)) ?? ""
        self.creatorName = (try? c.decode(String.self, forKey: .creatorName)) ?? ""
        self.memberCount = (try? c.decode(Int.self, forKey: .memberCount)) ?? 0
        self.postCount = (try? c.decode(Int.self, forKey: .postCount)) ?? 0
        self.rules = (try? c.decode(String.self, forKey: .rules)) ?? ""
        self.tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        self.location = try? c.decode(GeoPoint.self, forKey: .location)
        self.geohash = try? c.decode(String.self, forKey: .geohash)
        self.radiusKm = try? c.decode(Double.self, forKey: .radiusKm)
        self.breedFilter = try? c.decode(String.self, forKey: .breedFilter)
        self.isVerified = (try? c.decode(Bool.self, forKey: .isVerified)) ?? false
        self.isFeatured = (try? c.decode(Bool.self, forKey: .isFeatured)) ?? false
        self.isArchived = (try? c.decode(Bool.self, forKey: .isArchived)) ?? false
        self.metadata = try? c.decode([String: String].self, forKey: .metadata)
        self.createdAt = Self.decodeMillis(c, key: .createdAt)
        self.updatedAt = Self.decodeMillis(c, key: .updatedAt)
    }

    init(
        id: String? = nil,
        name: String = "",
        description: String = "",
        type: CommunityType = .general,
        privacy: CommunityPrivacy = .public,
        coverPhotoUrl: String? = nil,
        iconUrl: String? = nil,
        createdBy: String = "",
        creatorName: String = "",
        memberCount: Int = 0,
        postCount: Int = 0,
        rules: String = "",
        tags: [String] = [],
        location: GeoPoint? = nil,
        geohash: String? = nil,
        radiusKm: Double? = nil,
        breedFilter: String? = nil,
        isVerified: Bool = false,
        isFeatured: Bool = false,
        isArchived: Bool = false,
        metadata: [String: String]? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000,
        updatedAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
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
        self.location = location
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

    /// Tolerant millis-decoder. Accepts Number (Long/Double) directly, falls
    /// back to Firestore Timestamp by reading the seconds/nanoseconds, and
    /// drops to "now" if the field is absent (e.g. brand-new docs that haven't
    /// landed the server-side createdAt write yet).
    private static func decodeMillis(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double {
        if let n = try? container.decode(Double.self, forKey: key) { return n }
        if let n = try? container.decode(Int64.self, forKey: key) { return Double(n) }
        if let ts = try? container.decode(Timestamp.self, forKey: key) {
            return ts.dateValue().timeIntervalSince1970 * 1000
        }
        return Date().timeIntervalSince1970 * 1000
    }
}

// MARK: - Firestore write helper

extension Community {
    /// Map representation matching Android's `Community.toMap()` for direct
    /// `setData` / `updateData` writes when `Codable` round-trip isn't
    /// suitable (e.g. preserving GeoPoint native types).
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "description": description,
            "type": type.rawValue,
            "privacy": privacy.rawValue,
            "createdBy": createdBy,
            "creatorName": creatorName,
            "memberCount": memberCount,
            "postCount": postCount,
            "rules": rules,
            "tags": tags,
            "isVerified": isVerified,
            "isFeatured": isFeatured,
            "isArchived": isArchived,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        if let coverPhotoUrl { data["coverPhotoUrl"] = coverPhotoUrl }
        if let iconUrl { data["iconUrl"] = iconUrl }
        if let location { data["location"] = location }
        if let geohash { data["geohash"] = geohash }
        if let radiusKm { data["radiusKm"] = radiusKm }
        if let breedFilter { data["breedFilter"] = breedFilter }
        if let metadata { data["metadata"] = metadata }
        return data
    }
}
