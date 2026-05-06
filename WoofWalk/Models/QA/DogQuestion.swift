import Foundation
import FirebaseFirestore

// MARK: - QuestionCategory

/// Mirrors `data.model.QuestionCategory` on Android — raw value is the enum
/// case name written to Firestore (e.g. "GENERAL", "HEALTH"). Cross-client
/// reads/writes share the same uppercase tokens.
enum QuestionCategory: String, Codable, CaseIterable, Identifiable {
    case general = "GENERAL"
    case health = "HEALTH"
    case behavior = "BEHAVIOR"
    case training = "TRAINING"
    case nutrition = "NUTRITION"
    case grooming = "GROOMING"
    case exercise = "EXERCISE"

    var id: String { rawValue }

    /// Title-cased label for UI ("General", "Health", ...). Matches Android's
    /// `category.name.lowercase().replaceFirstChar { it.uppercase() }` pattern.
    var displayName: String {
        let lower = rawValue.lowercased()
        guard let first = lower.first else { return rawValue }
        return first.uppercased() + lower.dropFirst()
    }

    var iconSystemName: String {
        switch self {
        case .general: return "questionmark.circle.fill"
        case .health: return "cross.case.fill"
        case .behavior: return "brain.head.profile"
        case .training: return "graduationcap.fill"
        case .nutrition: return "leaf.fill"
        case .grooming: return "scissors"
        case .exercise: return "figure.walk"
        }
    }

    static func from(_ raw: String?) -> QuestionCategory {
        guard let raw else { return .general }
        return QuestionCategory(rawValue: raw.uppercased()) ?? .general
    }
}

// MARK: - DogQuestion

/// A community Q&A question. Path: `dog_questions/{questionId}`. Field names
/// match the Android `DogQuestion` data class one-for-one — both clients read
/// & write the same docs. Answers live in the `answers` subcollection
/// (see `DogAnswer`).
///
/// `id` is a plain optional (not `@DocumentID`) to match the project's
/// preferred decoding pattern (see `Community.swift` for the rationale).
/// `QARepository` populates `id` from `doc.documentID` after decode via
/// `DocumentSnapshot.decodeDogQuestion()`.
///
/// `createdAt` / `updatedAt` are `@ServerTimestamp` on Android and arrive as
/// Firestore `Timestamp` on the wire. They're stored here as optional `Date`
/// so freshly-created docs (where the server hasn't stamped yet) don't crash
/// the decoder.
///
/// `authorPhotoUrl` is the field added in the recent profile-pic audit so the
/// Q&A list/detail can render the asker's avatar without a per-row user
/// fetch. The repo writes it from the canonical `users/{uid}.photoURL` field
/// at question-creation time.
struct DogQuestion: Identifiable, Codable, Equatable {
    var id: String?
    var authorId: String = ""
    var authorName: String = ""
    var authorPhotoUrl: String?
    var title: String = ""
    var question: String = ""
    var category: QuestionCategory = .general
    var tags: [String] = []
    var imageUrls: [String] = []
    var answerCount: Int = 0
    var viewCount: Int = 0
    var upvotes: Int = 0
    var hasAcceptedAnswer: Bool = false
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case authorId, authorName, authorPhotoUrl
        case title, question, category
        case tags, imageUrls
        case answerCount, viewCount, upvotes, hasAcceptedAnswer
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(String.self, forKey: .id)
        self.authorId = (try? c.decode(String.self, forKey: .authorId)) ?? ""
        self.authorName = (try? c.decode(String.self, forKey: .authorName)) ?? ""
        // Android writes the canonical `photoURL` field for users; we accept
        // either casing here for forward-compat with any docs that get
        // backfilled with the iOS-style camelCase key.
        self.authorPhotoUrl = (try? c.decode(String.self, forKey: .authorPhotoUrl))
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.question = (try? c.decode(String.self, forKey: .question)) ?? ""
        if let categoryRaw = try? c.decode(String.self, forKey: .category) {
            self.category = QuestionCategory.from(categoryRaw)
        }
        self.tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        self.imageUrls = (try? c.decode([String].self, forKey: .imageUrls)) ?? []
        self.answerCount = (try? c.decode(Int.self, forKey: .answerCount)) ?? 0
        self.viewCount = (try? c.decode(Int.self, forKey: .viewCount)) ?? 0
        self.upvotes = (try? c.decode(Int.self, forKey: .upvotes)) ?? 0
        self.hasAcceptedAnswer = (try? c.decode(Bool.self, forKey: .hasAcceptedAnswer)) ?? false
        self.createdAt = Self.decodeDate(c, key: .createdAt)
        self.updatedAt = Self.decodeDate(c, key: .updatedAt)
    }

    init(
        id: String? = nil,
        authorId: String = "",
        authorName: String = "",
        authorPhotoUrl: String? = nil,
        title: String = "",
        question: String = "",
        category: QuestionCategory = .general,
        tags: [String] = [],
        imageUrls: [String] = [],
        answerCount: Int = 0,
        viewCount: Int = 0,
        upvotes: Int = 0,
        hasAcceptedAnswer: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorPhotoUrl = authorPhotoUrl
        self.title = title
        self.question = question
        self.category = category
        self.tags = tags
        self.imageUrls = imageUrls
        self.answerCount = answerCount
        self.viewCount = viewCount
        self.upvotes = upvotes
        self.hasAcceptedAnswer = hasAcceptedAnswer
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Tolerant timestamp decoder. Android emits Firestore `Timestamp`s via
    /// `@ServerTimestamp`; older docs may have epoch-ms ints/doubles in the
    /// same field. Returns nil while the server-side stamp is pending so the
    /// UI can show a "just now" placeholder rather than crashing.
    private static func decodeDate(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        if let ts = try? container.decode(Timestamp.self, forKey: key) {
            return ts.dateValue()
        }
        if let n = try? container.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: n / 1000)
        }
        if let n = try? container.decode(Int64.self, forKey: key) {
            return Date(timeIntervalSince1970: Double(n) / 1000)
        }
        return nil
    }
}

// MARK: - Firestore write helper

extension DogQuestion {
    /// Map representation for direct `addDocument(data:)` writes. Mirrors
    /// Android's create payload — the server-side Firestore rules check
    /// `request.resource.data.authorId == request.auth.uid` and require a
    /// timestamp `createdAt`, so we send `FieldValue.serverTimestamp()` to
    /// satisfy both clients consistently.
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "authorId": authorId,
            "authorName": authorName,
            "title": title,
            "question": question,
            "category": category.rawValue,
            "tags": tags,
            "imageUrls": imageUrls,
            "answerCount": answerCount,
            "viewCount": viewCount,
            "upvotes": upvotes,
            "hasAcceptedAnswer": hasAcceptedAnswer,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let authorPhotoUrl { data["authorPhotoUrl"] = authorPhotoUrl }
        return data
    }
}
