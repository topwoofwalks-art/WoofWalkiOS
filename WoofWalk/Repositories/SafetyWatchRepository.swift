import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

/// Watch Me repository — wraps the europe-west2 Cloud Function gateway.
/// All reads + writes against `/safety_watches` go through callables; the
/// security rules block direct client access. Mirror docs at
/// `/users/{uid}/watched_walks/{watchId}` are also CF-only.
///
/// Mirrors Android `SafetyWatchRepository`. Keep callable names + payload
/// keys in sync with `functions/src/notifications/watchMe.ts`.
final class SafetyWatchRepository {
    static let shared = SafetyWatchRepository()

    private let auth = Auth.auth()
    private lazy var functions = Functions.functions(region: "europe-west2")

    private init() {}

    // MARK: - Walker-side

    /// Start a new safety watch for the given walk session.
    ///
    /// `clientToken` is a pre-generated 32-char hex UUID — the caller fires
    /// the share intent in parallel with this CF call so WhatsApp / SMS
    /// opens immediately rather than after the round-trip. The CF accepts
    /// our token after a UUID-shape sanity check; if `nil`, the CF
    /// generates one and we don't gain the parallel-share latency win.
    func startWatch(
        sessionId: String,
        walkerFirstName: String,
        walkerNote: String,
        guardianNames: [String],
        guardianPhones: [String],
        guardianUids: [String],
        expectedReturnAt: Int64,
        clientToken: String? = nil
    ) async throws -> SafetyWatch {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "SafetyWatchRepository", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let payload: [String: Any] = [
            "sessionId": sessionId,
            "walkerFirstName": walkerFirstName,
            "walkerNote": walkerNote,
            "guardianNames": guardianNames,
            "guardianPhones": guardianPhones,
            "guardianUids": guardianUids,
            "expectedReturnAt": expectedReturnAt,
            "clientToken": clientToken ?? ""
        ]

        let result = try await functions
            .httpsCallable("startSafetyWatch")
            .call(payload)

        guard let data = result.data as? [String: Any],
              let id = data["id"] as? String,
              let token = data["token"] as? String else {
            throw NSError(domain: "SafetyWatchRepository", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "startSafetyWatch missing id/token"])
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let watch = SafetyWatch(
            id: id,
            sessionId: sessionId,
            userId: uid,
            token: token,
            walkerFirstName: walkerFirstName,
            walkerNote: walkerNote,
            guardianNames: guardianNames,
            guardianPhones: guardianPhones,
            guardianUids: guardianUids,
            expectedReturnAt: expectedReturnAt,
            lastCheckInAt: now,
            createdAt: now
        )
        print("[SafetyWatch] Started via CF: id=\(id) token=\(token) uids=\(guardianUids.count)")
        return watch
    }

    /// Push the latest GPS fix onto the watch doc. Throttled by the caller
    /// to one push every 10 s.
    func pushLocation(
        watchId: String,
        lat: Double,
        lng: Double,
        distanceMeters: Double,
        durationSec: Int64,
        routePoints: [[String: Double]]
    ) async throws {
        let payload: [String: Any] = [
            "watchId": watchId,
            "lat": lat,
            "lng": lng,
            "distanceMeters": distanceMeters,
            "durationSec": durationSec,
            "routePoints": routePoints
        ]
        _ = try await functions
            .httpsCallable("pushSafetyWatchLocation")
            .call(payload)
    }

    /// Walker tapped "I'm OK" on the check-in prompt.
    func recordCheckIn(watchId: String) async throws {
        _ = try await functions
            .httpsCallable("recordSafetyWatchCheckIn")
            .call(["watchId": watchId])
    }

    /// Walker confirmed PANIC (long-press completed).
    func triggerPanic(watchId: String) async throws {
        _ = try await functions
            .httpsCallable("triggerSafetyWatchPanic")
            .call(["watchId": watchId])
    }

    /// Walker confirmed they arrived safely.
    func markArrived(watchId: String) async throws {
        _ = try await functions
            .httpsCallable("markSafetyWatchArrived")
            .call(["watchId": watchId])
    }

    /// Walker cancelled the watch (e.g. picked the wrong guardian, changed
    /// their mind). Final state.
    func cancelWatch(watchId: String) async throws {
        _ = try await functions
            .httpsCallable("cancelSafetyWatch")
            .call(["watchId": watchId])
    }

    // MARK: - Guardian-side

    func acceptInvite(watchId: String) async throws {
        _ = try await functions
            .httpsCallable("acceptSafetyWatchInvite")
            .call(["watchId": watchId])
    }

    func declineInvite(watchId: String) async throws {
        _ = try await functions
            .httpsCallable("declineSafetyWatchInvite")
            .call(["watchId": watchId])
    }

    /// Live state of a single watch — for the in-app guardian view.
    /// Walker can also call this for their own watches.
    func getWatch(watchId: String) async throws -> SafetyWatchSnapshot {
        let result = try await functions
            .httpsCallable("getMyWatchedWalk")
            .call(["watchId": watchId])
        guard let data = result.data as? [String: Any] else {
            throw NSError(domain: "SafetyWatchRepository", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "getMyWatchedWalk returned no data"])
        }
        return SafetyWatchSnapshot.fromMap(data)
    }

    /// List the caller's mirror docs (walks they're a guardian on),
    /// newest first.
    func listMyWatchedWalks() async throws -> [WatchedWalkSummary] {
        let result = try await functions
            .httpsCallable("listMyWatchedWalks")
            .call()
        guard let data = result.data as? [String: Any],
              let rows = data["watches"] as? [[String: Any]] else {
            return []
        }
        return rows.compactMap { m in
            guard let watchId = m["watchId"] as? String else { return nil }
            return WatchedWalkSummary(
                watchId: watchId,
                walkerUid: m["walkerUid"] as? String ?? "",
                walkerFirstName: m["walkerFirstName"] as? String ?? "",
                status: m["status"] as? String ?? "ACTIVE",
                createdAt: (m["createdAt"] as? NSNumber)?.int64Value ?? 0,
                expiresAt: (m["expiresAt"] as? NSNumber)?.int64Value ?? 0,
                lastLat: (m["lastLat"] as? NSNumber)?.doubleValue ?? 0,
                lastLng: (m["lastLng"] as? NSNumber)?.doubleValue ?? 0,
                lastUpdatedAt: (m["lastUpdatedAt"] as? NSNumber)?.int64Value ?? 0,
                panicTriggeredAt: (m["panicTriggeredAt"] as? NSNumber)?.int64Value ?? 0,
                declined: m["declined"] as? Bool ?? false,
                accepted: m["accepted"] as? Bool ?? false
            )
        }
    }

    /// Public token-only fetch — no auth required (token IS the credential).
    /// Used by the deep-link viewer (when a guardian opens the SMS link).
    func getByToken(token: String) async throws -> SafetyWatchSnapshot {
        let result = try await functions
            .httpsCallable("getSafetyWatchByToken")
            .call(["token": token])
        guard let data = result.data as? [String: Any] else {
            throw NSError(domain: "SafetyWatchRepository", code: 500,
                          userInfo: [NSLocalizedDescriptionKey: "getSafetyWatchByToken returned no data"])
        }
        return SafetyWatchSnapshot.fromMap(data)
    }

    /// Build the public watch URL for sharing.
    func watchUrl(token: String) -> String {
        return "https://woofwalk.app/watch/\(token)"
    }
}
