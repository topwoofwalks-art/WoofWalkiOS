import Foundation
import FirebaseAuth
import FirebaseFirestore
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
    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions(region: "europe-west2")

    /// Collection holding every business live-share doc, public-readable
    /// by design (token == access credential). Authenticated clients can
    /// also query by `participantBookingIds` for their own recap.
    private static let collection = "live_share_links"

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

    // MARK: - Client recap (Phase 5)

    /// Fetch the recap projection of a live-share for the household
    /// represented by `bookingId`. Used by the client app on the
    /// post-walk recap surface to show the walker's photos, note,
    /// and branded close-out.
    ///
    /// Strategy: query `live_share_links` where
    /// `participantBookingIds array-contains bookingId` ordered by
    /// `createdAt` desc, take the first hit. Direct Firestore reads
    /// are allowed under the existing rule (auth-only). The returned
    /// recap filters `participants` to the viewer's own booking so a
    /// client only sees their own dog — privacy parity with the
    /// public portal's per-viewer filter.
    ///
    /// Returns `nil` when no share exists for the booking. Errors
    /// (network, decode) propagate; callers should treat them as
    /// "no recap available" rather than a hard failure.
    func fetchRecapForBooking(bookingId: String) async throws -> BusinessLiveShareRecap? {
        guard auth.currentUser != nil else {
            throw NSError(
                domain: "BusinessLiveShareRepository", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }
        guard !bookingId.isEmpty else { return nil }

        // Look for the most-recent share doc that names this booking
        // as a participant. ordering by createdAt picks the latest if
        // multiple historical shares exist for the same booking
        // (recurring weekly walks, etc.).
        let snap = try await db.collection(Self.collection)
            .whereField("participantBookingIds", arrayContains: bookingId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        guard let shareDoc = snap.documents.first else { return nil }
        let d = shareDoc.data()
        let shareId = (d["id"] as? String) ?? shareDoc.documentID

        // Photos subcollection — best-effort; an empty/missing
        // collection just means no photos were captured.
        var photos: [BusinessLiveSharePhoto] = []
        do {
            let photoSnap = try await shareDoc.reference.collection("photos")
                .order(by: "takenAt", descending: false)
                .limit(to: 50)
                .getDocuments()
            photos = photoSnap.documents.compactMap { Self.mapPhoto($0) }
        } catch {
            print("[BusinessLiveShareRepo] photo subcollection read failed: \(error)")
        }

        // Filter participants to this client's booking. Mirrors the
        // CF's per-viewer privacy filter — without this a stale share
        // doc could leak other households' dogs by name + photo.
        let allParticipants = (d["participants"] as? [[String: Any]]) ?? []
        let visibleParticipants: [[String: Any]] = {
            // Solo walks (1 participant) bypass the filter.
            guard allParticipants.count > 1 else { return allParticipants }
            return allParticipants.filter { ($0["bookingId"] as? String) == bookingId }
        }()
        let participants = visibleParticipants.compactMap { Self.mapParticipant($0) }

        return BusinessLiveShareRecap(
            id: shareId,
            walkSessionId: (d["walkSessionId"] as? String) ?? (d["sessionId"] as? String),
            walkEnded: (d["walkEnded"] as? Bool) ?? false,
            walkerNote: (d["walkerNote"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            walkerNoteUpdatedAt: Self.readInt64(d["walkerNoteUpdatedAt"]),
            lastUpdatedAt: Self.readInt64(d["lastUpdatedAt"]),
            scheduledEndAt: Self.readInt64(d["scheduledEndAt"]),
            distanceMeters: (d["distanceMeters"] as? Double) ?? 0,
            durationSec: Self.readInt64(d["durationSec"]) ?? 0,
            walkerDisplayName: (d["walkerDisplayName"] as? String)
                ?? (d["walkerFirstName"] as? String),
            walkerPhotoUrl: d["walkerPhotoUrl"] as? String,
            orgId: d["orgId"] as? String,
            orgName: d["orgName"] as? String,
            orgLogoUrl: d["orgLogoUrl"] as? String,
            orgBrandColour: d["orgBrandColour"] as? String,
            participants: participants,
            photos: photos
        )
    }

    // MARK: - Decode helpers

    private static func mapPhoto(_ doc: QueryDocumentSnapshot) -> BusinessLiveSharePhoto? {
        let d = doc.data()
        guard let storageUrl = d["storageUrl"] as? String, !storageUrl.isEmpty else { return nil }
        return BusinessLiveSharePhoto(
            id: (d["id"] as? String) ?? doc.documentID,
            storageUrl: storageUrl,
            thumbnailUrl: (d["thumbnailUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            caption: (d["caption"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            takenAt: readInt64(d["takenAt"]) ?? 0,
            lat: d["lat"] as? Double,
            lng: d["lng"] as? Double
        )
    }

    private static func mapParticipant(_ raw: [String: Any]) -> BusinessLiveShareParticipant? {
        let bookingId = (raw["bookingId"] as? String) ?? ""
        guard !bookingId.isEmpty else { return nil }
        let dogsRaw = (raw["dogs"] as? [[String: Any]]) ?? []
        let dogs = dogsRaw.compactMap { dogDict -> BusinessLiveShareDog? in
            let id = (dogDict["id"] as? String) ?? ""
            let name = (dogDict["name"] as? String) ?? ""
            guard !name.isEmpty else { return nil }
            return BusinessLiveShareDog(
                id: id.isEmpty ? name : id,
                name: name,
                photoUrl: (dogDict["photoUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            )
        }
        return BusinessLiveShareParticipant(
            bookingId: bookingId,
            clientName: (raw["clientName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            dogs: dogs
        )
    }

    /// Firestore returns numeric fields as either Int64, Int, or Double
    /// depending on how they were written. Normalise to Int64.
    private static func readInt64(_ raw: Any?) -> Int64? {
        if let v = raw as? Int64 { return v }
        if let v = raw as? Int { return Int64(v) }
        if let v = raw as? Double { return Int64(v) }
        if let v = raw as? NSNumber { return v.int64Value }
        return nil
    }
}
