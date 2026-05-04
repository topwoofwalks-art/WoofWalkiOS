import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Combine

/// Meet & Greet repository — wraps the 6 callable Cloud Functions in
/// `functions/src/meetGreet/meetGreet.ts` and exposes Firestore
/// listeners for the thread doc + message subcollection.
///
/// Pattern mirrors `BusinessLiveShareRepository` — every mutation is
/// a CF callable; reads are direct Firestore listeners scoped through
/// `meet_greet_threads/{threadId}` rules.
///
/// Region pinned to `europe-west2` (matches the CF + the rest of the
/// app's callables).
final class MeetGreetRepository {
    static let shared = MeetGreetRepository()

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions(region: "europe-west2")

    private init() {}

    // MARK: - Mutations (Cloud Functions)

    struct CreateResult {
        let threadId: String
        let existing: Bool
    }

    /// Create (or resume) a Meet & Greet thread. The CF refuses if
    /// the same client already has an OPEN thread with this provider
    /// for this dog and returns `existing: true` with the existing id.
    func createRequest(
        providerOrgId: String,
        dogId: String,
        introMessage: String,
        roughArea: String
    ) async throws -> CreateResult {
        try requireAuth()
        let payload: [String: Any] = [
            "providerOrgId": providerOrgId,
            "dogId": dogId,
            "introMessage": introMessage,
            "roughArea": roughArea,
        ]
        let result = try await functions.httpsCallable("createMeetGreetRequest").call(payload)
        guard let data = result.data as? [String: Any],
              let threadId = data["threadId"] as? String else {
            throw makeError(500, "Invalid createMeetGreetRequest response")
        }
        let existing = (data["existing"] as? Bool) ?? false
        return CreateResult(threadId: threadId, existing: existing)
    }

    /// Append a plain-text message to the thread.
    func sendMessage(threadId: String, text: String) async throws {
        try requireAuth()
        let payload: [String: Any] = ["threadId": threadId, "text": text]
        _ = try await functions.httpsCallable("sendMeetGreetMessage").call(payload)
    }

    /// Either side proposes a meet time + public-friendly location
    /// label (e.g. "Crook town park"). Flips status to `time_proposed`.
    func proposeTime(
        threadId: String,
        startMs: Int64,
        durationMin: Int,
        locationLabel: String
    ) async throws {
        try requireAuth()
        let payload: [String: Any] = [
            "threadId": threadId,
            "startMs": startMs,
            "durationMin": durationMin,
            "locationLabel": locationLabel,
        ]
        _ = try await functions.httpsCallable("proposeMeetGreetTime").call(payload)
    }

    /// The OTHER side accepts the proposed time. CF unlocks the
    /// provider's exact address, phone, email at this point.
    func confirmTime(threadId: String) async throws {
        try requireAuth()
        let payload: [String: Any] = ["threadId": threadId]
        _ = try await functions.httpsCallable("confirmMeetGreetTime").call(payload)
    }

    /// Cancel the thread. Optional `reason` is appended to the
    /// timeline as a system message.
    func cancel(threadId: String, reason: String? = nil) async throws {
        try requireAuth()
        var payload: [String: Any] = ["threadId": threadId]
        if let reason, !reason.isEmpty {
            payload["reason"] = reason
        }
        _ = try await functions.httpsCallable("cancelMeetGreet").call(payload)
    }

    /// Mark the meet as complete after the scheduled time. Unlocks
    /// the "Book a full service" up-sell on the recap card.
    func complete(threadId: String) async throws {
        try requireAuth()
        let payload: [String: Any] = ["threadId": threadId]
        _ = try await functions.httpsCallable("completeMeetGreet").call(payload)
    }

    // MARK: - Listeners (Firestore)

    /// Live thread doc. Emits whenever the CF (or another participant)
    /// updates fields like `status`, `proposedTime`, `exactAddress`, …
    func observeThread(threadId: String) -> AnyPublisher<MeetGreetThread?, Error> {
        let subject = PassthroughSubject<MeetGreetThread?, Error>()
        let registration = db.collection("meet_greet_threads")
            .document(threadId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                guard let snapshot, snapshot.exists else {
                    subject.send(nil)
                    return
                }
                do {
                    let thread = try snapshot.data(as: MeetGreetThread.self)
                    subject.send(thread)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }
        return subject
            .handleEvents(receiveCancel: { registration.remove() })
            .eraseToAnyPublisher()
    }

    /// Live message stream, ordered by `createdAt` ascending.
    func observeMessages(threadId: String) -> AnyPublisher<[MeetGreetMessage], Error> {
        let subject = PassthroughSubject<[MeetGreetMessage], Error>()
        let registration = db.collection("meet_greet_threads")
            .document(threadId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                let messages: [MeetGreetMessage] = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: MeetGreetMessage.self)
                } ?? []
                subject.send(messages)
            }
        return subject
            .handleEvents(receiveCancel: { registration.remove() })
            .eraseToAnyPublisher()
    }

    /// Client-side inbox — every thread where the current uid is the
    /// requester. Used by `MeetGreetInboxScreen` in `.client` mode.
    func observeMyClientThreads() -> AnyPublisher<[MeetGreetThread], Error> {
        let subject = PassthroughSubject<[MeetGreetThread], Error>()
        guard let uid = auth.currentUser?.uid else {
            subject.send([])
            return subject.eraseToAnyPublisher()
        }
        let registration = db.collection("meet_greet_threads")
            .whereField("clientUid", isEqualTo: uid)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                let threads: [MeetGreetThread] = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: MeetGreetThread.self)
                } ?? []
                subject.send(threads)
            }
        return subject
            .handleEvents(receiveCancel: { registration.remove() })
            .eraseToAnyPublisher()
    }

    /// Provider-side inbox — every thread targeting the given
    /// `providerOrgId`. Used by `MeetGreetInboxScreen` in `.provider`
    /// mode. Mirrors the Android `observeProviderThreads(orgId)` path.
    /// The Firestore rules verify the caller is an org member; the
    /// `whereField` here scopes the query to this org so the rule's
    /// `list` evaluator can prove the constraint without a per-doc
    /// `get()`.
    func observeProviderThreads(providerOrgId: String) -> AnyPublisher<[MeetGreetThread], Error> {
        let subject = PassthroughSubject<[MeetGreetThread], Error>()
        let registration = db.collection("meet_greet_threads")
            .whereField("providerOrgId", isEqualTo: providerOrgId)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                let threads: [MeetGreetThread] = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: MeetGreetThread.self)
                } ?? []
                subject.send(threads)
            }
        return subject
            .handleEvents(receiveCancel: { registration.remove() })
            .eraseToAnyPublisher()
    }

    // MARK: - Helpers

    private func requireAuth() throws {
        if auth.currentUser == nil {
            throw makeError(401, "Sign-in required")
        }
    }

    private func makeError(_ code: Int, _ message: String) -> NSError {
        NSError(
            domain: "MeetGreetRepository",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
