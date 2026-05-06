import Foundation
import FirebaseFirestore

/// Reasons for reporting community content. Matches Android's
/// `ReportReason` enum names — keeps the moderation pipeline's
/// `processCommunityReport` Cloud Function happy with either client.
/// (Distinct from the `ReportReason` private enum in
/// `Views/Social/ReportPostSheet.swift`, which is scoped to the regular
/// feed report flow.)
enum CommunityReportReason: String, Codable, CaseIterable, Identifiable {
    case spam = "SPAM"
    case harassment = "HARASSMENT"
    case hateSpeech = "HATE_SPEECH"
    case violence = "VIOLENCE"
    case animalCruelty = "ANIMAL_CRUELTY"
    case inappropriateContent = "INAPPROPRIATE_CONTENT"
    case misinformation = "MISINFORMATION"
    case scam = "SCAM"
    case privacyViolation = "PRIVACY_VIOLATION"
    case offTopic = "OFF_TOPIC"
    case other = "OTHER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: return "Spam or misleading"
        case .harassment: return "Harassment or bullying"
        case .hateSpeech: return "Hate speech or discrimination"
        case .violence: return "Violence or dangerous behaviour"
        case .animalCruelty: return "Animal cruelty or abuse"
        case .inappropriateContent: return "Inappropriate or explicit content"
        case .misinformation: return "Misinformation or false claims"
        case .scam: return "Scam or fraud"
        case .privacyViolation: return "Privacy violation"
        case .offTopic: return "Off-topic or irrelevant"
        case .other: return "Other"
        }
    }

    var iconSystemName: String {
        switch self {
        case .spam: return "envelope.badge.shield.half.filled"
        case .harassment: return "person.crop.circle.badge.exclamationmark"
        case .hateSpeech: return "exclamationmark.bubble"
        case .violence: return "exclamationmark.triangle"
        case .animalCruelty: return "pawprint.circle"
        case .inappropriateContent: return "eye.slash"
        case .misinformation: return "questionmark.circle"
        case .scam: return "creditcard.trianglebadge.exclamationmark"
        case .privacyViolation: return "lock.shield"
        case .offTopic: return "arrow.uturn.backward"
        case .other: return "ellipsis.circle"
        }
    }

    static func from(_ raw: String?) -> CommunityReportReason {
        guard let raw else { return .other }
        return CommunityReportReason(rawValue: raw.uppercased()) ?? .other
    }
}

enum CommunityReportStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case underReview = "UNDER_REVIEW"
    case resolved = "RESOLVED"
    case dismissed = "DISMISSED"

    static func from(_ raw: String?) -> CommunityReportStatus {
        guard let raw else { return .pending }
        return CommunityReportStatus(rawValue: raw.uppercased()) ?? .pending
    }
}

enum CommunityReportTargetType: String, Codable, CaseIterable {
    case post = "POST"
    case comment = "COMMENT"
    case member = "MEMBER"
    case community = "COMMUNITY"
    case event = "EVENT"
}

/// A report filed against community content or members. Path:
/// `community_reports/{reportId}` (top-level, NOT nested under the
/// community). Reads filter `whereField("communityId", ...)`.
struct CommunityReport: Identifiable, Codable {
    var id: String?
    var communityId: String = ""
    var reporterUserId: String = ""
    var reporterUserName: String = ""
    var targetType: CommunityReportTargetType = .post
    var targetId: String = ""
    var targetAuthorId: String = ""
    var reason: CommunityReportReason = .other
    var description: String = ""
    var screenshotUrls: [String] = []
    var status: CommunityReportStatus = .pending
    var reviewedByUserId: String?
    var reviewedByUserName: String?
    var reviewNote: String?
    var actionTaken: String?
    var resolvedAt: Double?
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    var isPending: Bool { status == .pending }
    var isResolved: Bool { status == .resolved }

    enum CodingKeys: String, CodingKey {
        case id
        case communityId
        case reporterUserId, reporterUserName
        case targetType, targetId, targetAuthorId
        case reason, description, screenshotUrls
        case status
        case reviewedByUserId, reviewedByUserName, reviewNote, actionTaken
        case resolvedAt, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.communityId = (try? c.decode(String.self, forKey: .communityId)) ?? ""
        self.reporterUserId = (try? c.decode(String.self, forKey: .reporterUserId)) ?? ""
        self.reporterUserName = (try? c.decode(String.self, forKey: .reporterUserName)) ?? ""
        if let t = try? c.decode(String.self, forKey: .targetType),
           let parsed = CommunityReportTargetType(rawValue: t.uppercased()) {
            self.targetType = parsed
        }
        self.targetId = (try? c.decode(String.self, forKey: .targetId)) ?? ""
        self.targetAuthorId = (try? c.decode(String.self, forKey: .targetAuthorId)) ?? ""
        self.reason = CommunityReportReason.from(try? c.decode(String.self, forKey: .reason))
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.screenshotUrls = (try? c.decode([String].self, forKey: .screenshotUrls)) ?? []
        self.status = CommunityReportStatus.from(try? c.decode(String.self, forKey: .status))
        self.reviewedByUserId = try? c.decode(String.self, forKey: .reviewedByUserId)
        self.reviewedByUserName = try? c.decode(String.self, forKey: .reviewedByUserName)
        self.reviewNote = try? c.decode(String.self, forKey: .reviewNote)
        self.actionTaken = try? c.decode(String.self, forKey: .actionTaken)
        self.resolvedAt = try? c.decode(Double.self, forKey: .resolvedAt)
        if let n = try? c.decode(Double.self, forKey: .createdAt) {
            self.createdAt = n
        } else if let ts = try? c.decode(Timestamp.self, forKey: .createdAt) {
            self.createdAt = ts.dateValue().timeIntervalSince1970 * 1000
        } else {
            self.createdAt = Date().timeIntervalSince1970 * 1000
        }
    }

    init(
        id: String? = nil,
        communityId: String = "",
        reporterUserId: String = "",
        reporterUserName: String = "",
        targetType: CommunityReportTargetType = .post,
        targetId: String = "",
        targetAuthorId: String = "",
        reason: CommunityReportReason = .other,
        description: String = "",
        screenshotUrls: [String] = [],
        status: CommunityReportStatus = .pending,
        reviewedByUserId: String? = nil,
        reviewedByUserName: String? = nil,
        reviewNote: String? = nil,
        actionTaken: String? = nil,
        resolvedAt: Double? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.communityId = communityId
        self.reporterUserId = reporterUserId
        self.reporterUserName = reporterUserName
        self.targetType = targetType
        self.targetId = targetId
        self.targetAuthorId = targetAuthorId
        self.reason = reason
        self.description = description
        self.screenshotUrls = screenshotUrls
        self.status = status
        self.reviewedByUserId = reviewedByUserId
        self.reviewedByUserName = reviewedByUserName
        self.reviewNote = reviewNote
        self.actionTaken = actionTaken
        self.resolvedAt = resolvedAt
        self.createdAt = createdAt
    }
}
