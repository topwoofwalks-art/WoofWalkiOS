import Foundation
import FirebaseFirestore

/// Lightweight chat-message struct for the community group chat tab. Path:
/// `communities/{communityId}/chat/{messageId}`. Mirrors Android's
/// `CommunityChatMessage` data class.
struct CommunityChatMessage: Identifiable, Codable, Equatable {
    var id: String?
    var authorId: String = ""
    var authorName: String = ""
    var authorPhotoUrl: String?
    var content: String = ""
    var createdAt: Double = Date().timeIntervalSince1970 * 1000

    enum CodingKeys: String, CodingKey {
        case id
        case authorId, authorName, authorPhotoUrl
        case content, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.authorId = (try? c.decode(String.self, forKey: .authorId)) ?? ""
        self.authorName = (try? c.decode(String.self, forKey: .authorName)) ?? ""
        self.authorPhotoUrl = try? c.decode(String.self, forKey: .authorPhotoUrl)
        self.content = (try? c.decode(String.self, forKey: .content)) ?? ""
        if let n = try? c.decode(Double.self, forKey: .createdAt) {
            self.createdAt = n
        } else if let n = try? c.decode(Int64.self, forKey: .createdAt) {
            self.createdAt = Double(n)
        } else if let ts = try? c.decode(Timestamp.self, forKey: .createdAt) {
            self.createdAt = ts.dateValue().timeIntervalSince1970 * 1000
        } else {
            self.createdAt = Date().timeIntervalSince1970 * 1000
        }
    }

    init(
        id: String? = nil,
        authorId: String = "",
        authorName: String = "",
        authorPhotoUrl: String? = nil,
        content: String = "",
        createdAt: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorPhotoUrl = authorPhotoUrl
        self.content = content
        self.createdAt = createdAt
    }

    var date: Date { Date(timeIntervalSince1970: createdAt / 1000) }
}
