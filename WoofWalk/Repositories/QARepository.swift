import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Mirrors `data.repository.QARepository` on Android. Owns CRUD + listeners
/// for community Q&A questions and answers, plus voting and accept-answer.
///
/// Backend collections (shared with Android):
///   - `dog_questions/{questionId}`
///   - `dog_questions/{questionId}/answers/{answerId}`
///
/// Firestore rules (see `firestore.rules` line ~2624) require:
///   - any authenticated user can read
///   - create requires `authorId == request.auth.uid` and a timestamp
///     `createdAt` — we send `FieldValue.serverTimestamp()`
///   - update/delete require the original author (or platform admin)
///
/// Note on `answerCount`: incrementing the parent question's `answerCount`
/// from a non-author client would fail the parent-update rule (only the
/// question author can update the parent doc), so we follow the Android
/// behaviour and skip the bump — the UI reads the answers subcollection
/// directly so the count is redundant. A future Cloud Function trigger
/// (`onAnswerCreated`) would be the right place to keep the denorm in sync.
final class QARepository {
    static let shared = QARepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    private init() {}

    private var questionsCollection: CollectionReference {
        db.collection("dog_questions")
    }

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    // MARK: - Post

    /// Post a new question. Returns the new document id. Mirrors Android's
    /// `postQuestion` — fetches the user's Firestore profile to populate
    /// `authorName` + `authorPhotoUrl` so the list/detail can render the
    /// avatar without a per-row user lookup.
    @discardableResult
    func postQuestion(
        title: String,
        question: String,
        category: QuestionCategory,
        tags: [String],
        imageUrls: [String]
    ) async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedBody.isEmpty else {
            throw makeError(400, "Title and question are required")
        }

        let (authorName, authorPhotoUrl) = await resolveAuthor(userId: currentUserId)

        let dogQuestion = DogQuestion(
            authorId: currentUserId,
            authorName: authorName,
            authorPhotoUrl: authorPhotoUrl,
            title: trimmedTitle,
            question: trimmedBody,
            category: category,
            tags: tags,
            imageUrls: imageUrls
        )

        let docRef = try await questionsCollection.addDocument(data: dogQuestion.toFirestoreData())
        print("[QARepo] Question posted: \(docRef.documentID)")
        return docRef.documentID
    }

    /// Post an answer to a question. Returns the new answer doc id.
    @discardableResult
    func postAnswer(questionId: String, answer: String) async throws -> String {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw makeError(400, "Answer is required")
        }

        let (authorName, authorPhotoUrl) = await resolveAuthor(userId: currentUserId)

        let dogAnswer = DogAnswer(
            questionId: questionId,
            authorId: currentUserId,
            authorName: authorName,
            authorPhotoUrl: authorPhotoUrl,
            answer: trimmed
        )

        let docRef = try await questionsCollection
            .document(questionId)
            .collection("answers")
            .addDocument(data: dogAnswer.toFirestoreData())

        // See class-doc note: parent answerCount stays stale here on purpose.
        print("[QARepo] Answer posted: \(docRef.documentID)")
        return docRef.documentID
    }

    // MARK: - Voting

    /// Toggle / flip an upvote on an answer. Mirrors Android's `upvoteAnswer`
    /// state-machine:
    ///   - already upvoted → clear (decrement upvotes, remove userVotes[uid])
    ///   - currently downvoted → flip (upvotes+1, downvotes-1, userVotes[uid]=1)
    ///   - no vote → upvote (upvotes+1, userVotes[uid]=1)
    func upvoteAnswer(questionId: String, answerId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let answerRef = questionsCollection
            .document(questionId)
            .collection("answers")
            .document(answerId)

        let snapshot = try await answerRef.getDocument()
        guard let answer = snapshot.decodeDogAnswer() else {
            throw makeError(404, "Answer not found")
        }
        let currentVote = answer.userVotes[currentUserId] ?? 0
        let userVoteKey = "userVotes.\(currentUserId)"

        switch currentVote {
        case 1:
            try await answerRef.updateData([
                "upvotes": FieldValue.increment(Int64(-1)),
                userVoteKey: FieldValue.delete()
            ])
        case -1:
            try await answerRef.updateData([
                "upvotes": FieldValue.increment(Int64(1)),
                "downvotes": FieldValue.increment(Int64(-1)),
                userVoteKey: 1
            ])
        default:
            try await answerRef.updateData([
                "upvotes": FieldValue.increment(Int64(1)),
                userVoteKey: 1
            ])
        }
        print("[QARepo] Answer upvoted: \(answerId)")
    }

    /// Toggle / flip a downvote on an answer. Mirror of `upvoteAnswer`.
    func downvoteAnswer(questionId: String, answerId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }
        let answerRef = questionsCollection
            .document(questionId)
            .collection("answers")
            .document(answerId)

        let snapshot = try await answerRef.getDocument()
        guard let answer = snapshot.decodeDogAnswer() else {
            throw makeError(404, "Answer not found")
        }
        let currentVote = answer.userVotes[currentUserId] ?? 0
        let userVoteKey = "userVotes.\(currentUserId)"

        switch currentVote {
        case -1:
            try await answerRef.updateData([
                "downvotes": FieldValue.increment(Int64(-1)),
                userVoteKey: FieldValue.delete()
            ])
        case 1:
            try await answerRef.updateData([
                "downvotes": FieldValue.increment(Int64(1)),
                "upvotes": FieldValue.increment(Int64(-1)),
                userVoteKey: -1
            ])
        default:
            try await answerRef.updateData([
                "downvotes": FieldValue.increment(Int64(1)),
                userVoteKey: -1
            ])
        }
        print("[QARepo] Answer downvoted: \(answerId)")
    }

    // MARK: - Accept

    /// Mark an answer as the accepted one. Caller must be the question author
    /// — server-side rules enforce, we check too for clean UX. Atomic batch:
    /// flips `isAccepted=true` on the chosen answer, clears it on every
    /// other answer in the subcollection, and bumps `hasAcceptedAnswer=true`
    /// on the parent question.
    func acceptAnswer(questionId: String, answerId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }

        let questionSnapshot = try await questionsCollection.document(questionId).getDocument()
        guard let question = questionSnapshot.decodeDogQuestion() else {
            throw makeError(404, "Question not found")
        }
        guard question.authorId == currentUserId else {
            throw makeError(403, "Only the question author can accept answers")
        }

        let answersSnapshot = try await questionsCollection
            .document(questionId)
            .collection("answers")
            .getDocuments()

        let batch = db.batch()
        for doc in answersSnapshot.documents {
            if doc.documentID == answerId {
                batch.updateData(["isAccepted": true], forDocument: doc.reference)
            } else {
                batch.updateData(["isAccepted": false], forDocument: doc.reference)
            }
        }
        batch.updateData([
            "hasAcceptedAnswer": true,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: questionsCollection.document(questionId))

        try await batch.commit()
        print("[QARepo] Answer accepted: \(answerId)")
    }

    // MARK: - View count

    /// Bump the question's `viewCount` by one. Best-effort — failures are
    /// logged but not surfaced to the UI (a stale view count isn't worth
    /// blocking the detail screen).
    func incrementViewCount(questionId: String) async {
        do {
            try await questionsCollection.document(questionId).updateData([
                "viewCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("[QARepo] incrementViewCount failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Listeners

    /// Live questions list, optionally filtered by category. 50-doc cap
    /// matches Android's `query.limit(50)`. Sends `[]` on permission-denied
    /// or any other error rather than throwing into the publisher chain.
    func listenQuestions(category: QuestionCategory? = nil, limit: Int = 50) -> AnyPublisher<[DogQuestion], Never> {
        let subject = CurrentValueSubject<[DogQuestion], Never>([])

        var query: Query = questionsCollection
        if let category {
            query = query.whereField("category", isEqualTo: category.rawValue)
        }
        query = query.order(by: "createdAt", descending: true).limit(to: limit)

        let listener = query.addSnapshotListener { snapshot, error in
            if let error {
                print("[QARepo] questions listener error: \(error.localizedDescription)")
                subject.send([])
                return
            }
            let questions = snapshot?.documents.compactMap { $0.decodeDogQuestion() } ?? []
            subject.send(questions)
        }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Live single-question listener for the detail screen. Sends `nil` on
    /// missing-doc or error.
    func listenQuestion(questionId: String) -> AnyPublisher<DogQuestion?, Never> {
        let subject = CurrentValueSubject<DogQuestion?, Never>(nil)
        let listener = questionsCollection.document(questionId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[QARepo] question listener error: \(error.localizedDescription)")
                    subject.send(nil)
                    return
                }
                subject.send(snapshot?.decodeDogQuestion())
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    /// Live answers listener for one question. Sorted accepted-first then by
    /// score — matches Android's
    /// `compareByDescending(isAccepted).thenByDescending(score)`.
    func listenAnswers(questionId: String) -> AnyPublisher<[DogAnswer], Never> {
        let subject = CurrentValueSubject<[DogAnswer], Never>([])
        let listener = questionsCollection
            .document(questionId)
            .collection("answers")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[QARepo] answers listener error: \(error.localizedDescription)")
                    subject.send([])
                    return
                }
                let answers = (snapshot?.documents.compactMap { $0.decodeDogAnswer() } ?? [])
                let sorted = answers.sorted { lhs, rhs in
                    if lhs.isAccepted != rhs.isAccepted {
                        return lhs.isAccepted && !rhs.isAccepted
                    }
                    return lhs.score > rhs.score
                }
                subject.send(sorted)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    // MARK: - Delete

    /// Delete a question and its answers. Caller must be the original
    /// author. Mirrors Android's batch delete: walk every answer, batch-
    /// delete each, then delete the parent.
    func deleteQuestion(questionId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw makeError(401, "User not authenticated")
        }

        let questionSnapshot = try await questionsCollection.document(questionId).getDocument()
        guard let question = questionSnapshot.decodeDogQuestion() else {
            throw makeError(404, "Question not found")
        }
        guard question.authorId == currentUserId else {
            throw makeError(403, "Only the question author can delete the question")
        }

        let answersSnapshot = try await questionsCollection
            .document(questionId)
            .collection("answers")
            .getDocuments()

        let batch = db.batch()
        for doc in answersSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        batch.deleteDocument(questionsCollection.document(questionId))
        try await batch.commit()
        print("[QARepo] Question deleted: \(questionId)")
    }

    // MARK: - Helpers

    /// Read the user's display name + canonical photo URL from Firestore.
    /// Reads the canonical Android `photoURL` field first, then the
    /// camelCase `photoUrl` fallback so iOS-style writes still resolve.
    /// Falls back to `auth.currentUser` for the name when the user doc
    /// is missing or stale.
    private func resolveAuthor(userId: String) async -> (name: String, photoUrl: String?) {
        var name = auth.currentUser?.displayName ?? ""
        var photoUrl: String? = auth.currentUser?.photoURL?.absoluteString
        do {
            let snapshot = try await usersCollection.document(userId).getDocument()
            // Prefer `username` to match Android — UserProfile.username is
            // what the Android repo writes into authorName. Display name
            // fallback only kicks in if username is blank.
            if let username = snapshot.get("username") as? String, !username.isEmpty {
                name = username
            } else if let displayName = snapshot.get("displayName") as? String, !displayName.isEmpty {
                name = displayName
            }
            if let url = snapshot.get("photoURL") as? String, !url.isEmpty {
                photoUrl = url
            } else if let url = snapshot.get("photoUrl") as? String, !url.isEmpty {
                photoUrl = url
            }
        } catch {
            print("[QARepo] resolveAuthor: \(error.localizedDescription)")
        }
        if name.isEmpty { name = "Anonymous" }
        return (name, photoUrl)
    }

    private func makeError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "QARepository", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// MARK: - Decoding helpers

/// Helpers for decoding Firestore docs into Q&A models. Each model uses a
/// plain `id: String?` (not `@DocumentID`) — see `DogQuestion.swift` for the
/// reasoning. These helpers populate `id` from `documentID` after the
/// throwing `data(as:)` call so callers don't have to remember the manual
/// step everywhere. Same pattern as `CommunityCodableExtensions`.
extension DocumentSnapshot {
    func decodeDogQuestion() -> DogQuestion? {
        var q = try? data(as: DogQuestion.self)
        if q?.id == nil { q?.id = documentID }
        return q
    }

    func decodeDogAnswer() -> DogAnswer? {
        var a = try? data(as: DogAnswer.self)
        if a?.id == nil { a?.id = documentID }
        return a
    }
}

extension QueryDocumentSnapshot {
    func decodeDogQuestion() -> DogQuestion? { (self as DocumentSnapshot).decodeDogQuestion() }
    func decodeDogAnswer() -> DogAnswer? { (self as DocumentSnapshot).decodeDogAnswer() }
}
