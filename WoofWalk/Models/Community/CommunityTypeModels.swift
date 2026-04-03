import Foundation
import FirebaseFirestore

// MARK: - Adoption Listing

/// Type-specific data for ADOPTION_LISTING posts
struct AdoptionListing: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var postId: String
    var dogName: String
    var breed: String
    var age: Int
    var sex: String
    var photoUrls: [String]
    var description: String
    var healthStatus: String
    var isNeutered: Bool
    var isVaccinated: Bool
    var isMicrochipped: Bool
    var temperament: String
    var goodWithKids: Bool
    var goodWithDogs: Bool
    var goodWithCats: Bool
    var specialNeeds: String?
    var contactInfo: String
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var status: String
    var createdBy: String
    var createdAt: Double
    var updatedAt: Double

    init(id: String? = nil,
         communityId: String = "",
         postId: String = "",
         dogName: String = "",
         breed: String = "",
         age: Int = 0,
         sex: String = "",
         photoUrls: [String] = [],
         description: String = "",
         healthStatus: String = "",
         isNeutered: Bool = false,
         isVaccinated: Bool = false,
         isMicrochipped: Bool = false,
         temperament: String = "",
         goodWithKids: Bool = false,
         goodWithDogs: Bool = false,
         goodWithCats: Bool = false,
         specialNeeds: String? = nil,
         contactInfo: String = "",
         locationName: String = "",
         latitude: Double? = nil,
         longitude: Double? = nil,
         status: String = "AVAILABLE",
         createdBy: String = "",
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         updatedAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.postId = postId
        self.dogName = dogName
        self.breed = breed
        self.age = age
        self.sex = sex
        self.photoUrls = photoUrls
        self.description = description
        self.healthStatus = healthStatus
        self.isNeutered = isNeutered
        self.isVaccinated = isVaccinated
        self.isMicrochipped = isMicrochipped
        self.temperament = temperament
        self.goodWithKids = goodWithKids
        self.goodWithDogs = goodWithDogs
        self.goodWithCats = goodWithCats
        self.specialNeeds = specialNeeds
        self.contactInfo = contactInfo
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.status = status
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Walk Schedule

/// Type-specific data for WALK_SCHEDULE posts
struct WalkSchedule: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var postId: String
    var title: String
    var description: String
    var createdBy: String
    var creatorName: String
    var startTime: Double
    var endTime: Double?
    var meetingPointName: String
    var meetingLatitude: Double?
    var meetingLongitude: Double?
    var routeId: String?
    var estimatedDistanceKm: Double?
    var estimatedDurationMin: Int?
    var difficulty: String
    var maxParticipants: Int?
    var participantIds: [String]
    var dogFriendlinessLevel: String
    var isCancelled: Bool
    var isRecurring: Bool
    var recurrenceRule: String?
    var createdAt: Double
    var updatedAt: Double

    init(id: String? = nil,
         communityId: String = "",
         postId: String = "",
         title: String = "",
         description: String = "",
         createdBy: String = "",
         creatorName: String = "",
         startTime: Double = Date().timeIntervalSince1970 * 1000,
         endTime: Double? = nil,
         meetingPointName: String = "",
         meetingLatitude: Double? = nil,
         meetingLongitude: Double? = nil,
         routeId: String? = nil,
         estimatedDistanceKm: Double? = nil,
         estimatedDurationMin: Int? = nil,
         difficulty: String = "EASY",
         maxParticipants: Int? = nil,
         participantIds: [String] = [],
         dogFriendlinessLevel: String = "ALL_WELCOME",
         isCancelled: Bool = false,
         isRecurring: Bool = false,
         recurrenceRule: String? = nil,
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         updatedAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.postId = postId
        self.title = title
        self.description = description
        self.createdBy = createdBy
        self.creatorName = creatorName
        self.startTime = startTime
        self.endTime = endTime
        self.meetingPointName = meetingPointName
        self.meetingLatitude = meetingLatitude
        self.meetingLongitude = meetingLongitude
        self.routeId = routeId
        self.estimatedDistanceKm = estimatedDistanceKm
        self.estimatedDurationMin = estimatedDurationMin
        self.difficulty = difficulty
        self.maxParticipants = maxParticipants
        self.participantIds = participantIds
        self.dogFriendlinessLevel = dogFriendlinessLevel
        self.isCancelled = isCancelled
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func isFull() -> Bool {
        guard let max = maxParticipants else { return false }
        return participantIds.count >= max
    }

    func isParticipating(userId: String) -> Bool {
        return participantIds.contains(userId)
    }
}

// MARK: - Puppy Milestone

/// Type-specific data for PUPPY_MILESTONE posts
struct PuppyMilestone: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var postId: String
    var dogId: String
    var dogName: String
    var milestoneType: String
    var title: String
    var description: String
    var photoUrls: [String]
    var ageWeeks: Int
    var createdBy: String
    var createdAt: Double

    init(id: String? = nil,
         communityId: String = "",
         postId: String = "",
         dogId: String = "",
         dogName: String = "",
         milestoneType: String = "",
         title: String = "",
         description: String = "",
         photoUrls: [String] = [],
         ageWeeks: Int = 0,
         createdBy: String = "",
         createdAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.postId = postId
        self.dogId = dogId
        self.dogName = dogName
        self.milestoneType = milestoneType
        self.title = title
        self.description = description
        self.photoUrls = photoUrls
        self.ageWeeks = ageWeeks
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}

// MARK: - Training Progress

/// Type-specific data for TRAINING_TIP / progress update posts
struct TrainingProgress: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var postId: String
    var dogId: String
    var dogName: String
    var skillName: String
    var category: String
    var progressPercent: Int
    var notes: String
    var videoUrl: String?
    var beforePhotoUrl: String?
    var afterPhotoUrl: String?
    var sessionsCompleted: Int
    var createdBy: String
    var createdAt: Double
    var updatedAt: Double

    init(id: String? = nil,
         communityId: String = "",
         postId: String = "",
         dogId: String = "",
         dogName: String = "",
         skillName: String = "",
         category: String = "",
         progressPercent: Int = 0,
         notes: String = "",
         videoUrl: String? = nil,
         beforePhotoUrl: String? = nil,
         afterPhotoUrl: String? = nil,
         sessionsCompleted: Int = 0,
         createdBy: String = "",
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         updatedAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.postId = postId
        self.dogId = dogId
        self.dogName = dogName
        self.skillName = skillName
        self.category = category
        self.progressPercent = progressPercent
        self.notes = notes
        self.videoUrl = videoUrl
        self.beforePhotoUrl = beforePhotoUrl
        self.afterPhotoUrl = afterPhotoUrl
        self.sessionsCompleted = sessionsCompleted
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Breed Alert

/// Type-specific data for BREED_ALERT posts
struct BreedAlert: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var postId: String
    var breed: String
    var alertType: String
    var title: String
    var description: String
    var severity: String
    var sourceUrl: String?
    var affectedRegions: [String]
    var isVerified: Bool
    var createdBy: String
    var createdAt: Double

    init(id: String? = nil,
         communityId: String = "",
         postId: String = "",
         breed: String = "",
         alertType: String = "",
         title: String = "",
         description: String = "",
         severity: String = "INFO",
         sourceUrl: String? = nil,
         affectedRegions: [String] = [],
         isVerified: Bool = false,
         createdBy: String = "",
         createdAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.postId = postId
        self.breed = breed
        self.alertType = alertType
        self.title = title
        self.description = description
        self.severity = severity
        self.sourceUrl = sourceUrl
        self.affectedRegions = affectedRegions
        self.isVerified = isVerified
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}

// MARK: - Destination Review

/// Type-specific data for DESTINATION_REVIEW posts
struct DestinationReview: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var postId: String
    var destinationName: String
    var destinationType: String
    var latitude: Double?
    var longitude: Double?
    var locationName: String
    var rating: Double
    var review: String
    var photoUrls: [String]
    var dogFriendlinessRating: Double
    var hasWaterBowls: Bool
    var hasOffLeadArea: Bool
    var hasDogMenu: Bool
    var isAccessible: Bool
    var visitDate: Double?
    var createdBy: String
    var createdAt: Double

    init(id: String? = nil,
         communityId: String = "",
         postId: String = "",
         destinationName: String = "",
         destinationType: String = "",
         latitude: Double? = nil,
         longitude: Double? = nil,
         locationName: String = "",
         rating: Double = 0.0,
         review: String = "",
         photoUrls: [String] = [],
         dogFriendlinessRating: Double = 0.0,
         hasWaterBowls: Bool = false,
         hasOffLeadArea: Bool = false,
         hasDogMenu: Bool = false,
         isAccessible: Bool = false,
         visitDate: Double? = nil,
         createdBy: String = "",
         createdAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.postId = postId
        self.destinationName = destinationName
        self.destinationType = destinationType
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.rating = rating
        self.review = review
        self.photoUrls = photoUrls
        self.dogFriendlinessRating = dogFriendlinessRating
        self.hasWaterBowls = hasWaterBowls
        self.hasOffLeadArea = hasOffLeadArea
        self.hasDogMenu = hasDogMenu
        self.isAccessible = isAccessible
        self.visitDate = visitDate
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}

// MARK: - Diet Plan

/// Type-specific data for DIET_PLAN posts
struct DietPlan: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var postId: String
    var dogId: String?
    var dogName: String
    var breed: String
    var ageYears: Int
    var weightKg: Double
    var planName: String
    var description: String
    var meals: [DietMeal]
    var supplements: [String]
    var allergies: [String]
    var vetApproved: Bool
    var vetName: String?
    var createdBy: String
    var createdAt: Double
    var updatedAt: Double

    init(id: String? = nil,
         communityId: String = "",
         postId: String = "",
         dogId: String? = nil,
         dogName: String = "",
         breed: String = "",
         ageYears: Int = 0,
         weightKg: Double = 0.0,
         planName: String = "",
         description: String = "",
         meals: [DietMeal] = [],
         supplements: [String] = [],
         allergies: [String] = [],
         vetApproved: Bool = false,
         vetName: String? = nil,
         createdBy: String = "",
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         updatedAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.postId = postId
        self.dogId = dogId
        self.dogName = dogName
        self.breed = breed
        self.ageYears = ageYears
        self.weightKg = weightKg
        self.planName = planName
        self.description = description
        self.meals = meals
        self.supplements = supplements
        self.allergies = allergies
        self.vetApproved = vetApproved
        self.vetName = vetName
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DietMeal: Codable {
    var name: String
    var time: String
    var ingredients: [String]
    var portionGrams: Double

    init(name: String = "",
         time: String = "",
         ingredients: [String] = [],
         portionGrams: Double = 0.0) {
        self.name = name
        self.time = time
        self.ingredients = ingredients
        self.portionGrams = portionGrams
    }
}

// MARK: - Competition Entry

/// Type-specific data for COMPETITION_ENTRY posts
struct CompetitionEntry: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var postId: String
    var dogId: String
    var dogName: String
    var competitionName: String
    var competitionType: String
    var eventDate: Double
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var placement: String?
    var score: Double?
    var photoUrls: [String]
    var videoUrl: String?
    var notes: String
    var createdBy: String
    var createdAt: Double

    init(id: String? = nil,
         communityId: String = "",
         postId: String = "",
         dogId: String = "",
         dogName: String = "",
         competitionName: String = "",
         competitionType: String = "",
         eventDate: Double = Date().timeIntervalSince1970 * 1000,
         locationName: String = "",
         latitude: Double? = nil,
         longitude: Double? = nil,
         placement: String? = nil,
         score: Double? = nil,
         photoUrls: [String] = [],
         videoUrl: String? = nil,
         notes: String = "",
         createdBy: String = "",
         createdAt: Double = Date().timeIntervalSince1970 * 1000) {
        self.id = id
        self.communityId = communityId
        self.postId = postId
        self.dogId = dogId
        self.dogName = dogName
        self.competitionName = competitionName
        self.competitionType = competitionType
        self.eventDate = eventDate
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.placement = placement
        self.score = score
        self.photoUrls = photoUrls
        self.videoUrl = videoUrl
        self.notes = notes
        self.createdBy = createdBy
        self.createdAt = createdAt
    }
}

// MARK: - Community Invite

/// Firestore path: communities/{communityId}/invites/{inviteId}
struct CommunityInvite: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var communityName: String
    var invitedBy: String
    var inviterName: String
    var inviteeUserId: String?
    var inviteeEmail: String?
    var role: String
    var status: String
    var message: String?
    var expiresAt: Double?
    var createdAt: Double
    var respondedAt: Double?

    init(id: String? = nil,
         communityId: String = "",
         communityName: String = "",
         invitedBy: String = "",
         inviterName: String = "",
         inviteeUserId: String? = nil,
         inviteeEmail: String? = nil,
         role: String = CommunityMemberRole.MEMBER.rawValue,
         status: String = "PENDING",
         message: String? = nil,
         expiresAt: Double? = nil,
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         respondedAt: Double? = nil) {
        self.id = id
        self.communityId = communityId
        self.communityName = communityName
        self.invitedBy = invitedBy
        self.inviterName = inviterName
        self.inviteeUserId = inviteeUserId
        self.inviteeEmail = inviteeEmail
        self.role = role
        self.status = status
        self.message = message
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.respondedAt = respondedAt
    }

    func isPending() -> Bool {
        return status == "PENDING"
    }

    func isExpired() -> Bool {
        guard let expires = expiresAt else { return false }
        return Date().timeIntervalSince1970 * 1000 > expires
    }
}

// MARK: - Community Join Request

/// Firestore path: communities/{communityId}/joinRequests/{requestId}
struct CommunityJoinRequest: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var userId: String
    var displayName: String
    var photoUrl: String?
    var message: String
    var status: String
    var reviewedBy: String?
    var reviewerName: String?
    var rejectionReason: String?
    var createdAt: Double
    var reviewedAt: Double?

    init(id: String? = nil,
         communityId: String = "",
         userId: String = "",
         displayName: String = "",
         photoUrl: String? = nil,
         message: String = "",
         status: String = "PENDING",
         reviewedBy: String? = nil,
         reviewerName: String? = nil,
         rejectionReason: String? = nil,
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         reviewedAt: Double? = nil) {
        self.id = id
        self.communityId = communityId
        self.userId = userId
        self.displayName = displayName
        self.photoUrl = photoUrl
        self.message = message
        self.status = status
        self.reviewedBy = reviewedBy
        self.reviewerName = reviewerName
        self.rejectionReason = rejectionReason
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
    }

    func isPending() -> Bool {
        return status == "PENDING"
    }

    func isApproved() -> Bool {
        return status == "APPROVED"
    }

    func isRejected() -> Bool {
        return status == "REJECTED"
    }
}

// MARK: - Report Reason

enum ReportReason: String, Codable, CaseIterable {
    case SPAM
    case HARASSMENT
    case INAPPROPRIATE_CONTENT
    case MISINFORMATION
    case ANIMAL_CRUELTY
    case SCAM
    case OFF_TOPIC
    case HATE_SPEECH
    case PERSONAL_INFORMATION
    case OTHER
}

// MARK: - Community Report

/// Firestore path: communities/{communityId}/reports/{reportId}
struct CommunityReport: Identifiable, Codable {
    @DocumentID var id: String?
    var communityId: String
    var reportedBy: String
    var reporterName: String
    var targetType: String
    var targetId: String
    var targetAuthorId: String?
    var reason: String
    var details: String
    var status: String
    var reviewedBy: String?
    var reviewerName: String?
    var resolution: String?
    var createdAt: Double
    var reviewedAt: Double?

    init(id: String? = nil,
         communityId: String = "",
         reportedBy: String = "",
         reporterName: String = "",
         targetType: String = "POST",
         targetId: String = "",
         targetAuthorId: String? = nil,
         reason: String = ReportReason.OTHER.rawValue,
         details: String = "",
         status: String = "PENDING",
         reviewedBy: String? = nil,
         reviewerName: String? = nil,
         resolution: String? = nil,
         createdAt: Double = Date().timeIntervalSince1970 * 1000,
         reviewedAt: Double? = nil) {
        self.id = id
        self.communityId = communityId
        self.reportedBy = reportedBy
        self.reporterName = reporterName
        self.targetType = targetType
        self.targetId = targetId
        self.targetAuthorId = targetAuthorId
        self.reason = reason
        self.details = details
        self.status = status
        self.reviewedBy = reviewedBy
        self.reviewerName = reviewerName
        self.resolution = resolution
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
    }

    func getReportReason() -> ReportReason {
        return ReportReason(rawValue: reason) ?? .OTHER
    }

    func isPending() -> Bool {
        return status == "PENDING"
    }

    func isResolved() -> Bool {
        return status == "RESOLVED"
    }
}
