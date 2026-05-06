import Foundation
import FirebaseFirestore

/// An answer to a `DogQuestion`. Path:
/// `dog_questions/{questionId}/answers/{answerId}`. Field names match the
/// Android `DogAnswer` data class one-for-one.
///
/// Vote tracking uses the same `userVotes: [userId: Int]` map shape as
/// Android (1 = up, -1 = down, missing = none) so the same Firestore docs
/// round-trip cleanly across clients. `score` is computed (`upvotes -
/// downvotes`) — Android exposes the same helper.
///
/// `id` is a plain optional (not `@DocumentID`) — see `DogQuestion.swift` for
/// the rationale. The repo populates `id` from `doc.documentID` after decode.
struct DogAnswer: Identifiable, Codable, Equatable {
    var id: String?
    var questionId: String = ""
    var authorId: String = ""
    var authorName: String = ""
    var authorPhotoUrl: String?
    var answer: String = ""
    var upvotes: Int = 0
    var downvotes: Int = 0
    var isAccepted: Bool = false
    var userVotes: [String: Int] = [:]
    var createdAt: Date?

    var score: Int { upvotes - downvotes }

    enum CodingKeys: String, CodingKey {
        case id
        case questionId, authorId, authorName, authorPhotoUrl
        case answer
        case upvotes, downvotes, isAccepted
        case userVotes
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.questionId = (try? c.decode(String.self, forKey: .questionId)) ?? ""
        self.authorId = (try? c.decode(String.self, forKey: .authorId)) ?? ""
        self.authorName = (try? c.decode(String.self, forKey: .authorName)) ?? ""
        self.authorPhotoUrl = try? c.decode(String.self, forKey: .authorPhotoUrl)
        self.answer = (try? c.decode(String.self, forKey: .answer)) ?? ""
        self.upvotes = (try? c.decode(Int.self, forKey: .upvotes)) ?? 0
        self.downvotes = (try? c.decode(Int.self, forKey: .downvotes)) ?? 0
        self.isAccepted = (try? c.decode(Bool.self, forKey: .isAccepted)) ?? false
        self.userVotes = (try? c.decode([String: Int].self, forKey: .userVotes)) ?? [:]
        if let ts = try? c.decode(Timestamp.self, forKey: .createdAt) {
            self.createdAt = ts.dateValue()
        } else if let n = try? c.decode(Double.self, forKey: .createdAt) {
            self.createdAt = Date(timeIntervalSince1970: n / 1000)
        } else if let n = try? c.decode(Int64.self, forKey: .createdAt) {
            self.createdAt = Date(timeIntervalSince1970: Double(n) / 1000)
        } else {
            self.createdAt = nil
        }
    }

    init(
        id: String? = nil,
        questionId: String = "",
        authorId: String = "",
        authorName: String = "",
        authorPhotoUrl: String? = nil,
        answer: String = "",
        upvotes: Int = 0,
        downvotes: Int = 0,
        isAccepted: Bool = false,
        userVotes: [String: Int] = [:],
        createdAt: Date? = nil
    ) {
        self.id = id
        self.questionId = questionId
        self.authorId = authorId
        self.authorName = authorName
        self.authorPhotoUrl = authorPhotoUrl
        self.answer = answer
        self.upvotes = upvotes
        self.downvotes = downvotes
        self.isAccepted = isAccepted
        self.userVotes = userVotes
        self.createdAt = createdAt
    }
}

// MARK: - Firestore write helper

extension DogAnswer {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "questionId": questionId,
            "authorId": authorId,
            "authorName": authorName,
            "answer": answer,
            "upvotes": upvotes,
            "downvotes": downvotes,
            "isAccepted": isAccepted,
            "userVotes": userVotes,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let authorPhotoUrl { data["authorPhotoUrl"] = authorPhotoUrl }
        return data
    }
}
