import Foundation
import FirebaseAuth
import FirebaseFunctions

/// Business walker → client live-walk share repository.
///
/// All writes route through Cloud Function callables (see
/// `functions/src/walks/businessLiveShare.ts`) — the public share
/// doc carries trust signals (DBS, insurance, org logo) projected
/// from sensitive collections that clients can't read directly under
/// tightened rules. Mirrors Android `BusinessLiveShareRepository`.
///
/// Keep callable names + payload keys in sync with the CF module and
/// the Android wrapper. See `BUSINESS_LIVE_WALK_DESIGN.md` (repo
/// root) for the full architecture.
///
/// **Note**: iOS doesn't yet have a business walker mode — this repo
/// is the data-layer entry point ready for when that UI lands. When
/// `WalkConsoleView.swift` (or equivalent) is built, this repo
/// becomes its share-layer dependency.
final class BusinessLiveShareRepository {
    static let shared = BusinessLiveShareRepository()

    private let auth = Auth.auth()
    private lazy var functions = Functions.functions(region: "europe-west2")

    private init() {}

    struct CreateResult {
        let id: String
        let token: String
        let url: String
    }

    /// Create (or reuse) a public live-share for the active walk.
    /// Caller must be the walker assigned to all `bookingIds`. If
    /// an active link already exists for this `sessionId`, the CF
    /// returns it (idempotent enough). Pass single-element list for
    /// solo walks; multi-element for group walks.
    func createShare(sessionId: String, bookingIds: [String]) async throws -> CreateResult {
        guard auth.currentUser != nil else {
            throw NSError(
                domain: "BusinessLiveShareRepository", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "bookingIds": bookingIds,
        ]
        let result = try await functions.httpsCallable("createBusinessLiveShare").call(payload)
        guard let data = result.data as? [String: Any],
              let id = data["id"] as? String,
              let token = data["token"] as? String,
              let url = data["url"] as? String else {
            throw NSError(
                domain: "BusinessLiveShareRepository", code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid CF response"]
            )
        }
        return CreateResult(id: id, token: token, url: url)
    }

    /// Push the latest accepted GPS fix + cumulative stats to the
    /// share doc. Throttle client-side; the CF re-validates auth and
    /// trims `routePoints` to the most recent 500. Pass `walkerNote`
    /// to update the walker's commentary; `clearWalkerNote: true`
    /// clears it; otherwise leaves the existing value.
    func pushLocation(
        shareId: String,
        lat: Double,
        lng: Double,
        distanceMeters: Double,
        durationSec: Int64,
        routePoints: [[String: Double]],
        walkerNote: String? = nil,
        clearWalkerNote: Bool = false
    ) async throws {
        var payload: [String: Any] = [
            "shareId": shareId,
            "lat": lat,
            "lng": lng,
            "distanceMeters": distanceMeters,
            "durationSec": durationSec,
            "routePoints": routePoints,
        ]
        if clearWalkerNote {
            payload["walkerNote"] = NSNull()
        } else if let note = walkerNote {
            payload["walkerNote"] = note
        }
        _ = try await functions.httpsCallable("pushBusinessLiveLocation").call(payload)
    }

    /// Record a geotagged photo against the active share. The image
    /// itself was already uploaded to Storage at `storagePath`; this
    /// CF call writes the metadata doc the public page reads.
    func addPhoto(
        shareId: String,
        storagePath: String,
        thumbnailPath: String? = nil,
        lat: Double,
        lng: Double,
        takenAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        caption: String? = nil
    ) async throws -> String {
        var payload: [String: Any] = [
            "shareId": shareId,
            "storagePath": storagePath,
            "lat": lat,
            "lng": lng,
            "takenAt": takenAt,
            "caption": caption ?? "",
        ]
        if let thumb = thumbnailPath {
            payload["thumbnailPath"] = thumb
        }
        let result = try await functions.httpsCallable("addBusinessLiveSharePhoto").call(payload)
        guard let data = result.data as? [String: Any],
              let photoId = data["photoId"] as? String else {
            throw NSError(
                domain: "BusinessLiveShareRepository", code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid addPhoto response"]
            )
        }
        return photoId
    }

    /// End the share — flips `walkEnded`, keeps the doc reachable
    /// for a 7-day recap window.
    func endShare(shareId: String) async throws {
        let payload: [String: Any] = ["shareId": shareId]
        _ = try await functions.httpsCallable("endBusinessLiveShare").call(payload)
    }

    /// Per-client share URL. Appends `?b={bookingId}` so the portal
    /// page highlights that household's dog. For solo walks (single
    /// element in the original `bookingIds`), returns the base URL
    /// unchanged.
    func perClientUrl(baseUrl: String, bookingId: String, isGroupWalk: Bool) -> String {
        guard isGroupWalk else { return baseUrl }
        let separator = baseUrl.contains("?") ? "&" : "?"
        return "\(baseUrl)\(separator)b=\(bookingId)"
    }
}
