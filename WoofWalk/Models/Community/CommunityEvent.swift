import Foundation
import FirebaseFirestore

enum CommunityEventStatus: String, Codable, CaseIterable {
    case upcoming = "UPCOMING"
    case ongoing = "ONGOING"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"

    static func from(_ raw: String?) -> CommunityEventStatus {
        guard let raw else { return .upcoming }
        return CommunityEventStatus(rawValue: raw.uppercased()) ?? .upcoming
    }
}

/// A community event (group walk, meetup). Path:
/// `communities/{communityId}/events/{eventId}`. Conflicts with
/// `Models/Social.swift::Event` were avoided by namespacing this type.
struct CommunityEvent: Identifiable, Codable, Equatable {
    var id: String?
    var communityId: String = ""
    var title: String = ""
    var description: String = ""
    var coverPhotoUrl: String?
    var organiserUserId: String = ""
    var organiserName: String = ""
    var status: CommunityEventStatus = .upcoming
    var location: GeoPoint?
    var locationName: String = ""
    var locationAddress: String = ""
    var startTime: Double = 0
    var endTime: Double = 0
    var maxAttendees: Int?
    var attendeeIds: [String] = []
    var attendeeCount: Int = 0
    var isRecurring: Bool = false
    var recurrenceRule: String?
    var tags: [String] = []
    var requiresDogs: Bool = true
    var allowedBreeds: [String] = []
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    var updatedAt: Double = Date().timeIntervalSince1970 * 1000

    func isAttending(_ userId: String) -> Bool { attendeeIds.contains(userId) }

    var isFull: Bool {
        guard let maxAttendees else { return false }
        return attendeeCount >= maxAttendees
    }

    var isUpcoming: Bool {
        status == .upcoming && startTime > Date().timeIntervalSince1970 * 1000
    }

    var startDate: Date {
        Date(timeIntervalSince1970: startTime / 1000)
    }

    var endDate: Date {
        Date(timeIntervalSince1970: endTime / 1000)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case communityId, title, description, coverPhotoUrl
        case organiserUserId, organiserName
        case status
        case location, locationName, locationAddress
        case startTime, endTime
        case maxAttendees, attendeeIds, attendeeCount
        case isRecurring, recurrenceRule
        case tags, requiresDogs, allowedBreeds
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.communityId = (try? c.decode(String.self, forKey: .communityId)) ?? ""
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.description = (try? c.decode(String.self, forKey: .description)) ?? ""
        self.coverPhotoUrl = try? c.decode(String.self, forKey: .coverPhotoUrl)
        self.organiserUserId = (try? c.decode(String.self, forKey: .organiserUserId)) ?? ""
        self.organiserName = (try? c.decode(String.self, forKey: .organiserName)) ?? ""
        self.status = CommunityEventStatus.from(try? c.decode(String.self, forKey: .status))
        self.location = try? c.decode(GeoPoint.self, forKey: .location)
        self.locationName = (try? c.decode(String.self, forKey: .locationName)) ?? ""
        self.locationAddress = (try? c.decode(String.self, forKey: .locationAddress)) ?? ""
        self.startTime = Self.decodeMillis(c, key: .startTime)
        self.endTime = Self.decodeMillis(c, key: .endTime)
        self.maxAttendees = try? c.decode(Int.self, forKey: .maxAttendees)
        self.attendeeIds = (try? c.decode([String].self, forKey: .attendeeIds)) ?? []
        self.attendeeCount = (try? c.decode(Int.self, forKey: .attendeeCount)) ?? 0
        self.isRecurring = (try? c.decode(Bool.self, forKey: .isRecurring)) ?? false
        self.recurrenceRule = try? c.decode(String.self, forKey: .recurrenceRule)
        self.tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        self.requiresDogs = (try? c.decode(Bool.self, forKey: .requiresDogs)) ?? true
        self.allowedBreeds = (try? c.decode([String].self, forKey: .allowedBreeds)) ?? []
        self.createdAt = Self.decodeMillis(c, key: .createdAt)
        self.updatedAt = Self.decodeMillis(c, key: .updatedAt)
    }

    init(
        id: String? = nil,
        communityId: String = "",
        title: String = "",
        description: String = "",
        coverPhotoUrl: String? = nil,
        organiserUserId: String = "",
        organiserName: String = "",
        status: CommunityEventStatus = .upcoming,
        location: GeoPoint? = nil,
        locationName: String = "",
        locationAddress: String = "",
        startTime: Double = 0,
        endTime: Double = 0,
        maxAttendees: Int? = nil,
        attendeeIds: [String] = [],
        attendeeCount: Int = 0,
        isRecurring: Bool = false,
        recurrenceRule: String? = nil,
        tags: [String] = [],
        requiresDogs: Bool = true,
        allowedBreeds: [String] = [],
        createdAt: Double = Date().timeIntervalSince1970 * 1000,
        updatedAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.communityId = communityId
        self.title = title
        self.description = description
        self.coverPhotoUrl = coverPhotoUrl
        self.organiserUserId = organiserUserId
        self.organiserName = organiserName
        self.status = status
        self.location = location
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.startTime = startTime
        self.endTime = endTime
        self.maxAttendees = maxAttendees
        self.attendeeIds = attendeeIds
        self.attendeeCount = attendeeCount
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.tags = tags
        self.requiresDogs = requiresDogs
        self.allowedBreeds = allowedBreeds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private static func decodeMillis(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double {
        if let n = try? container.decode(Double.self, forKey: key) { return n }
        if let n = try? container.decode(Int64.self, forKey: key) { return Double(n) }
        if let ts = try? container.decode(Timestamp.self, forKey: key) {
            return ts.dateValue().timeIntervalSince1970 * 1000
        }
        return 0
    }

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "communityId": communityId,
            "title": title,
            "description": description,
            "organiserUserId": organiserUserId,
            "organiserName": organiserName,
            "status": status.rawValue,
            "locationName": locationName,
            "locationAddress": locationAddress,
            "startTime": startTime,
            "endTime": endTime,
            "attendeeIds": attendeeIds,
            "attendeeCount": attendeeCount,
            "isRecurring": isRecurring,
            "tags": tags,
            "requiresDogs": requiresDogs,
            "allowedBreeds": allowedBreeds,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
        if let coverPhotoUrl { data["coverPhotoUrl"] = coverPhotoUrl }
        if let location { data["location"] = location }
        if let maxAttendees { data["maxAttendees"] = maxAttendees }
        if let recurrenceRule { data["recurrenceRule"] = recurrenceRule }
        return data
    }
}
