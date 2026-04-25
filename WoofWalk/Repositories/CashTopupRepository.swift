import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

// MARK: - Models

/// One message in the cash-topup conversation thread.
/// Mirrors `messages[]` element in `cash_booking_requests/{id}` per the
/// server contract in `functions/src/notifications/cashTopupRequests.ts`.
struct CashTopupMessage: Identifiable, Equatable {
    let id: String
    let from: String   // "client" | "business"
    let uid: String
    let text: String
    let at: Date

    var isFromClient: Bool { from == "client" }
    var isFromBusiness: Bool { from == "business" }
}

/// One cash-topup request thread.
struct CashTopupRequest: Identifiable, Equatable {
    let id: String
    let clientId: String
    let clientName: String
    let orgId: String
    let orgName: String?
    /// One of: pending | replied | resolved | fulfilled.
    let status: String
    let requestedAt: Date
    let lastMessageAt: Date
    let messageCount: Int
    let messages: [CashTopupMessage]

    var statusEnum: CashTopupStatus {
        CashTopupStatus(rawValue: status) ?? .pending
    }
}

enum CashTopupStatus: String {
    case pending
    case replied
    case resolved
    case fulfilled

    var displayLabel: String {
        switch self {
        case .pending:   return "Waiting"
        case .replied:   return "Replied"
        case .resolved:  return "Resolved"
        case .fulfilled: return "Top-up complete — book now!"
        }
    }
}

// MARK: - Errors

enum CashTopupError: LocalizedError {
    case notAuthenticated
    case alreadyOpen(requestId: String?)
    case notFound
    case invalidResponse
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You need to sign in first."
        case .alreadyOpen:
            return "You've already sent a request — we'll ping you when they reply."
        case .notFound:
            return "Cash top-up request not found."
        case .invalidResponse:
            return "Server returned an unexpected response."
        case .underlying(let err):
            return err.localizedDescription
        }
    }
}

// MARK: - Repository

/// Wrapper around the four `cashTopupRequests` Cloud Functions plus a
/// snapshot-listener helper for a single request doc.
///
/// Server contract (deployed, do not modify):
///   * `requestCashTopup({ orgId, message? }) -> { requestId, alreadyOpen }`
///   * `replyToCashTopupRequest({ requestId, text, markResolved? }) -> { ok, status }`
///   * `resolveCashTopupRequest({ requestId }) -> { ok }`
///   * `listOrgCashTopupRequests({ orgId, status?, limit? }) -> { requests: [...] }`
final class CashTopupRepository {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private lazy var functions = Functions.functions(region: "europe-west2")

    private static let collection = "cash_booking_requests"

    // MARK: Callables

    /// Idempotent: if an open request already exists for (caller, orgId)
    /// the CF returns the existing requestId with `alreadyOpen: true`. We
    /// surface that as `CashTopupError.alreadyOpen` so the UI can show a
    /// dedicated state rather than a generic error.
    func requestCashTopup(orgId: String, message: String? = nil) async throws -> String {
        guard auth.currentUser != nil else { throw CashTopupError.notAuthenticated }

        var payload: [String: Any] = ["orgId": orgId]
        if let msg = message?.trimmingCharacters(in: .whitespacesAndNewlines), !msg.isEmpty {
            payload["message"] = msg
        }

        do {
            let result = try await functions
                .httpsCallable("requestCashTopup")
                .call(payload)
            guard let data = result.data as? [String: Any],
                  let requestId = data["requestId"] as? String else {
                throw CashTopupError.invalidResponse
            }
            // CF currently returns alreadyOpen as a hint; not an error,
            // but UI may still want to know. Surface via dedicated error
            // when set so the caller can switch copy.
            if let alreadyOpen = data["alreadyOpen"] as? Bool, alreadyOpen {
                throw CashTopupError.alreadyOpen(requestId: requestId)
            }
            return requestId
        } catch let err as NSError {
            // The CF can also throw `already-exists` (FunctionsErrorCode 6)
            // pre-emptively if the same caller fires the callable while a
            // duplicate is mid-flight. Keep the alreadyOpen fast-path UI.
            if err.domain == FunctionsErrorDomain,
               err.code == FunctionsErrorCode.alreadyExists.rawValue {
                throw CashTopupError.alreadyOpen(requestId: nil)
            }
            throw err
        }
    }

    /// Business-side: append a reply, optionally flipping status to `resolved`.
    @discardableResult
    func replyToCashTopupRequest(
        requestId: String,
        text: String,
        markResolved: Bool = false
    ) async throws -> String {
        guard auth.currentUser != nil else { throw CashTopupError.notAuthenticated }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CashTopupError.invalidResponse
        }

        let payload: [String: Any] = [
            "requestId": requestId,
            "text": trimmed,
            "markResolved": markResolved
        ]
        let result = try await functions
            .httpsCallable("replyToCashTopupRequest")
            .call(payload)
        guard let data = result.data as? [String: Any],
              let status = data["status"] as? String else {
            throw CashTopupError.invalidResponse
        }
        return status
    }

    /// Business-side: explicitly mark resolved without sending a reply.
    func resolveCashTopupRequest(requestId: String) async throws {
        guard auth.currentUser != nil else { throw CashTopupError.notAuthenticated }
        let payload: [String: Any] = ["requestId": requestId]
        _ = try await functions
            .httpsCallable("resolveCashTopupRequest")
            .call(payload)
    }

    /// Business inbox feed. `status` defaults to "pending" server-side; pass
    /// "all" to skip the filter.
    func listOrgCashTopupRequests(
        orgId: String,
        status: String? = "pending",
        limit: Int = 20
    ) async throws -> [CashTopupRequest] {
        guard auth.currentUser != nil else { throw CashTopupError.notAuthenticated }

        var payload: [String: Any] = ["orgId": orgId, "limit": limit]
        if let status = status { payload["status"] = status }

        let result = try await functions
            .httpsCallable("listOrgCashTopupRequests")
            .call(payload)
        guard let data = result.data as? [String: Any],
              let raw = data["requests"] as? [[String: Any]] else {
            throw CashTopupError.invalidResponse
        }
        return raw.compactMap { Self.decodeRequest(from: $0, fallbackId: nil) }
    }

    // MARK: Realtime per-doc snapshot listener

    /// AsyncStream wrapper around Firestore's per-document snapshot listener.
    /// Cancelling the consuming Task removes the listener.
    ///
    /// Per-doc reads work for both client + claimed business users because
    /// `cash_booking_requests` rules grant `get` to participants. The list
    /// path is locked down — that's why business inbox uses the callable.
    func observeRequest(id requestId: String) -> AsyncStream<CashTopupRequest> {
        AsyncStream { continuation in
            let registration = db.collection(Self.collection)
                .document(requestId)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        // Surface via debug only — permission-denied is
                        // expected during sign-out / handoff.
                        print("[CashTopupRepository] observeRequest error: \(error.localizedDescription)")
                        return
                    }
                    guard let snap = snapshot, snap.exists,
                          let data = snap.data() else {
                        return
                    }
                    if let decoded = Self.decodeRequest(from: data, fallbackId: snap.documentID) {
                        continuation.yield(decoded)
                    }
                }

            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }

    // MARK: - Decoding

    /// Decode either a Firestore snapshot map or the JSON map returned by
    /// `listOrgCashTopupRequests`. Both share the same field names — the
    /// only fork is timestamp shape (Firestore Timestamp vs the CF's JSON
    /// `_seconds`/`_nanoseconds` envelope when admin-SDK serialises
    /// Timestamps).
    private static func decodeRequest(
        from data: [String: Any],
        fallbackId: String?
    ) -> CashTopupRequest? {
        let id = (data["id"] as? String) ?? fallbackId
        guard let id = id,
              let clientId = data["clientId"] as? String,
              let orgId = data["orgId"] as? String else {
            return nil
        }
        let status = (data["status"] as? String) ?? CashTopupStatus.pending.rawValue
        let clientName = (data["clientName"] as? String) ?? ""
        let orgName = data["orgName"] as? String
        let messageCount = (data["messageCount"] as? Int)
            ?? ((data["messageCount"] as? NSNumber)?.intValue ?? 0)

        let requestedAt = decodeDate(data["requestedAt"]) ?? Date(timeIntervalSince1970: 0)
        let lastMessageAt = decodeDate(data["lastMessageAt"]) ?? requestedAt

        let rawMessages = (data["messages"] as? [[String: Any]]) ?? []
        let messages = rawMessages.compactMap { decodeMessage(from: $0) }

        return CashTopupRequest(
            id: id,
            clientId: clientId,
            clientName: clientName,
            orgId: orgId,
            orgName: orgName,
            status: status,
            requestedAt: requestedAt,
            lastMessageAt: lastMessageAt,
            messageCount: messageCount,
            messages: messages.sorted { $0.at < $1.at }
        )
    }

    private static func decodeMessage(from data: [String: Any]) -> CashTopupMessage? {
        guard let id = data["id"] as? String,
              let from = data["from"] as? String,
              let uid = data["uid"] as? String,
              let text = data["text"] as? String else {
            return nil
        }
        let at = decodeDate(data["at"]) ?? Date()
        return CashTopupMessage(id: id, from: from, uid: uid, text: text, at: at)
    }

    /// Best-effort timestamp decode. Native Firestore listeners hand us
    /// `Timestamp`; the callable response bridges to Date via Firebase's
    /// auto-coercion when present, but on some SDK versions the wrapped
    /// JSON shape (`{ "_seconds": Int, "_nanoseconds": Int }`) leaks through.
    private static func decodeDate(_ value: Any?) -> Date? {
        if let ts = value as? Timestamp {
            return ts.dateValue()
        }
        if let date = value as? Date {
            return date
        }
        if let dict = value as? [String: Any] {
            if let secs = dict["_seconds"] as? Double {
                let nanos = (dict["_nanoseconds"] as? Double) ?? 0
                return Date(timeIntervalSince1970: secs + nanos / 1_000_000_000)
            }
            if let secs = dict["seconds"] as? Double {
                let nanos = (dict["nanoseconds"] as? Double) ?? 0
                return Date(timeIntervalSince1970: secs + nanos / 1_000_000_000)
            }
        }
        if let n = value as? NSNumber {
            // Epoch seconds heuristic.
            return Date(timeIntervalSince1970: n.doubleValue)
        }
        return nil
    }
}
