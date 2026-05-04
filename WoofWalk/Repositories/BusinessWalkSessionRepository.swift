import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

/// Repository for business walker walk-sessions. Mirrors Android
/// `BusinessWalkSessionRepository.kt`. Writes go directly to
/// `walk_sessions/{id}` (rules accept create when `walkerId == auth.uid`
/// and the doc carries an `orgId`).
///
/// Two entry points:
/// - `startWalkSession(bookingId, ...)` — single-booking walk.
/// - `startGroupWalkSession(bookingIds, ...)` — multi-booking walk
///   covering N bookings under a single org.
///
/// On end-of-walk, the booking statuses are flipped to COMPLETED and the
/// live-share is closed by `WalkConsoleViewModel` (the repo doesn't
/// own those side-effects to keep the seams clean).
final class BusinessWalkSessionRepository {
    static let shared = BusinessWalkSessionRepository()

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private static let collectionWalkSessions = "walk_sessions"
    private static let collectionBookings = "bookings"
    private static let collectionUsers = "users"
    private static let collectionIncidents = "incidents"
    private static let collectionCheckIns = "checkIns"
    private static let collectionNotifications = "notifications"

    private init() {}

    // MARK: - Session lifecycle

    /// Start a new single-booking walk session. Returns the new session id
    /// (Firestore `walk_sessions/{id}`). Requires the caller to be the
    /// walker assigned to the booking, and the booking to carry an `orgId`.
    func startWalkSession(
        bookingId: String,
        dogIds: [String],
        plannedRoute: [CLLocationCoordinate2D] = [],
        plannedWalkId: String? = nil
    ) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }
        guard !dogIds.isEmpty else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "At least one dog required"]
            )
        }

        // Booking provides org context. The walk_sessions create rule
        // requires walkerId == auth.uid AND orgId on the doc — without
        // it, the create silently rejects and the walker's screen
        // ends up half-initialised.
        let bookingDoc = try await db.collection(Self.collectionBookings)
            .document(bookingId)
            .getDocument()
        guard let bookingData = bookingDoc.data() else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Booking \(bookingId) not found"]
            )
        }
        let orgId = (bookingData["orgId"] as? String)
            ?? (bookingData["organizationId"] as? String)
            ?? ""
        guard !orgId.isEmpty else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Booking \(bookingId) missing orgId"]
            )
        }
        let clientId = bookingData["clientId"] as? String ?? ""
        let clientName = bookingData["clientName"] as? String ?? ""

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let sessionRef = db.collection(Self.collectionWalkSessions).document()
        let sessionId = sessionRef.documentID

        var sessionData: [String: Any] = [
            "bookingId": bookingId,
            "walkerId": userId,
            "orgId": orgId,
            "clientId": clientId,
            "clientName": clientName,
            "dogIds": dogIds,
            "startTime": now,
            "createdAt": now,
            "updatedAt": now,
            "status": BWSWalkStatus.inProgress.rawValue
        ]

        if !plannedRoute.isEmpty {
            sessionData["route"] = [
                "polyline": "",
                "coordinates": plannedRoute.map { ["lat": $0.latitude, "lng": $0.longitude] }
            ]
        }
        if let pwId = plannedWalkId {
            sessionData["plannedWalkId"] = pwId
        }

        try await sessionRef.setData(sessionData)

        // Fan out booking-side updates: status → IN_PROGRESS + walkId
        // attached. Best-effort — failure here doesn't kill the walk.
        await updateBookingForWalkStart(bookingId: bookingId, walkId: sessionId)

        print("[BusinessWalkSession] Started walk \(sessionId) for booking \(bookingId) org=\(orgId) dogs=\(dogIds.count)")
        return sessionId
    }

    /// Start a group walk covering multiple bookings under a single org.
    /// All bookings must share the same `orgId`; mismatch throws.
    func startGroupWalkSession(
        bookingIds: [String],
        dogIds: [String],
        plannedRoute: [CLLocationCoordinate2D] = [],
        plannedWalkId: String? = nil
    ) async throws -> String {
        guard !bookingIds.isEmpty else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "At least one bookingId required"]
            )
        }
        // Single-booking case → fall through to the single-booking path.
        if bookingIds.count == 1 {
            return try await startWalkSession(
                bookingId: bookingIds[0],
                dogIds: dogIds,
                plannedRoute: plannedRoute,
                plannedWalkId: plannedWalkId
            )
        }
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }
        guard !dogIds.isEmpty else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "At least one dog required"]
            )
        }

        // Resolve every booking + verify single shared orgId.
        var bookingDocs: [(id: String, data: [String: Any])] = []
        for id in bookingIds {
            let doc = try await db.collection(Self.collectionBookings)
                .document(id)
                .getDocument()
            guard let data = doc.data() else {
                throw NSError(
                    domain: "BusinessWalkSessionRepository", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Booking \(id) not found"]
                )
            }
            bookingDocs.append((id: id, data: data))
        }
        let orgIds = Set(bookingDocs.map { ($0.data["orgId"] as? String) ?? ($0.data["organizationId"] as? String) ?? "" })
        guard orgIds.count == 1, let orgId = orgIds.first, !orgId.isEmpty else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Group walk bookings must share a single orgId"]
            )
        }

        let primary = bookingDocs[0].data
        let clientId = primary["clientId"] as? String ?? ""
        let clientName = primary["clientName"] as? String ?? ""

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let sessionRef = db.collection(Self.collectionWalkSessions).document()
        let sessionId = sessionRef.documentID

        var sessionData: [String: Any] = [
            // Keep scalar `bookingId` for back-compat with the recap path.
            "bookingId": bookingIds[0],
            "bookingIds": bookingIds,
            "walkerId": userId,
            "orgId": orgId,
            "clientId": clientId,
            "clientName": clientName,
            "dogIds": dogIds,
            "startTime": now,
            "createdAt": now,
            "updatedAt": now,
            "status": BWSWalkStatus.inProgress.rawValue,
            "isGroupWalk": true
        ]
        if !plannedRoute.isEmpty {
            sessionData["route"] = [
                "polyline": "",
                "coordinates": plannedRoute.map { ["lat": $0.latitude, "lng": $0.longitude] }
            ]
        }
        if let pwId = plannedWalkId {
            sessionData["plannedWalkId"] = pwId
        }

        try await sessionRef.setData(sessionData)

        // Fan out booking-side updates across every booking in scope.
        for id in bookingIds {
            await updateBookingForWalkStart(bookingId: id, walkId: sessionId)
        }

        print("[BusinessWalkSession] Started GROUP walk \(sessionId) org=\(orgId) bookings=\(bookingIds.count) dogs=\(dogIds.count)")
        return sessionId
    }

    /// Best-effort: flip booking status → IN_PROGRESS and attach walkId.
    /// Failures log only; the walk continues regardless.
    private func updateBookingForWalkStart(bookingId: String, walkId: String) async {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        do {
            try await db.collection(Self.collectionBookings)
                .document(bookingId)
                .updateData([
                    "status": BookingStatus.inProgress.rawValue,
                    "walkId": walkId,
                    "updatedAt": now
                ])
        } catch {
            print("[BusinessWalkSession] Failed to update booking \(bookingId) on walk start: \(error)")
        }
    }

    /// Mark a walk-session document as completed. Walker-only path;
    /// `WalkConsoleViewModel.endWalk` calls this after stopping GPS.
    func completeSession(sessionId: String, distanceMeters: Double, durationSec: Int) async throws {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let durationHours = Double(durationSec) / 3600.0
        let distanceKm = distanceMeters / 1000.0
        let avgSpeedKmh = durationHours > 0 ? distanceKm / durationHours : 0
        let pace = distanceKm > 0 ? (Double(durationSec) / 60.0) / distanceKm : 0

        try await db.collection(Self.collectionWalkSessions)
            .document(sessionId)
            .setData([
                "status": BWSWalkStatus.completed.rawValue,
                "endTime": now,
                "lastUpdateTime": now,
                "stats": [
                    "distanceKm": distanceKm,
                    "durationSeconds": durationSec,
                    "averageSpeedKmh": avgSpeedKmh,
                    "currentPaceMinPerKm": pace
                ]
            ], merge: true)
    }

    /// Update an active walk's status (e.g. PAUSED). Doesn't touch end fields.
    func updateSessionStatus(sessionId: String, status: BWSWalkStatus) async throws {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try await db.collection(Self.collectionWalkSessions)
            .document(sessionId)
            .setData([
                "status": status.rawValue,
                "lastUpdateTime": now
            ], merge: true)
    }

    // MARK: - Dog check-ins

    /// Record a dog check-in. Two writes:
    ///  1. Authoritative `walk_sessions/{id}/checkIns/{dogId}` doc (so
    ///     the client live-share page sees the check-in chip).
    ///  2. Notification under the booking's clientId so the dog owner
    ///     gets a "Bella checked in" alert.
    func recordDogCheckIn(
        sessionId: String,
        bookingId: String?,
        dogId: String,
        dogName: String,
        note: String?,
        coordinate: CLLocationCoordinate2D?
    ) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        var checkInData: [String: Any] = [
            "dogId": dogId,
            "dogName": dogName,
            "note": note ?? "",
            "checkedInAt": now,
            "walkerId": userId
        ]
        if let coord = coordinate {
            checkInData["latLng"] = ["lat": coord.latitude, "lng": coord.longitude]
        }

        try await db.collection(Self.collectionWalkSessions)
            .document(sessionId)
            .collection(Self.collectionCheckIns)
            .document(dogId)
            .setData(checkInData)

        // Best-effort client notification.
        if let bookingId = bookingId {
            await notifyClientOfCheckIn(
                bookingId: bookingId,
                dogId: dogId,
                dogName: dogName,
                note: note,
                coordinate: coordinate
            )
        }
    }

    private func notifyClientOfCheckIn(
        bookingId: String,
        dogId: String,
        dogName: String,
        note: String?,
        coordinate: CLLocationCoordinate2D?
    ) async {
        do {
            let bookingDoc = try await db.collection(Self.collectionBookings)
                .document(bookingId)
                .getDocument()
            guard let clientId = bookingDoc.data()?["clientId"] as? String,
                  !clientId.isEmpty else { return }

            var data: [String: Any] = [
                "type": "WALK_CHECK_IN",
                "bookingId": bookingId,
                "dogId": dogId,
                "dogName": dogName,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "read": false
            ]
            if let note = note { data["note"] = note }
            if let coord = coordinate {
                data["location"] = ["lat": coord.latitude, "lng": coord.longitude]
            }
            _ = try await db.collection(Self.collectionUsers)
                .document(clientId)
                .collection(Self.collectionNotifications)
                .addDocument(data: data)
        } catch {
            print("[BusinessWalkSession] Failed to notify client of check-in: \(error)")
        }
    }

    // MARK: - Incidents

    /// Persist an incident under the walk session. HIGH / CRITICAL
    /// severities trigger an additional client notification.
    func saveIncident(
        sessionId: String,
        bookingId: String?,
        incident: WalkConsoleIncident
    ) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "BusinessWalkSessionRepository", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        var data: [String: Any] = [
            "id": incident.id,
            "type": incident.type.rawValue,
            "severity": incident.severity.rawValue,
            "notes": incident.notes,
            "timestamp": incident.timestamp,
            "walkerId": userId
        ]
        if let lat = incident.latitude, let lng = incident.longitude {
            data["latLng"] = ["lat": lat, "lng": lng]
        }

        try await db.collection(Self.collectionUsers)
            .document(userId)
            .collection(Self.collectionWalkSessions)
            .document(sessionId)
            .collection(Self.collectionIncidents)
            .document(incident.id)
            .setData(data)

        if (incident.severity == .high || incident.severity == .critical), let bookingId = bookingId {
            await notifyClientOfHighSeverityIncident(bookingId: bookingId, incident: incident)
        }
    }

    private func notifyClientOfHighSeverityIncident(bookingId: String, incident: WalkConsoleIncident) async {
        do {
            let bookingDoc = try await db.collection(Self.collectionBookings)
                .document(bookingId)
                .getDocument()
            guard let clientId = bookingDoc.data()?["clientId"] as? String,
                  !clientId.isEmpty else { return }

            let data: [String: Any] = [
                "type": "HIGH_SEVERITY_INCIDENT",
                "bookingId": bookingId,
                "incidentType": incident.type.rawValue,
                "severity": incident.severity.rawValue,
                "notes": incident.notes,
                "timestamp": incident.timestamp,
                "read": false
            ]
            _ = try await db.collection(Self.collectionUsers)
                .document(clientId)
                .collection(Self.collectionNotifications)
                .addDocument(data: data)
        } catch {
            print("[BusinessWalkSession] Failed to notify client of incident: \(error)")
        }
    }

    // MARK: - Photo upload

    /// Upload a photo to Firebase Storage at `live_walks/{shareId}/{photoId}.jpg`
    /// and return the storage path. The path is then handed to
    /// `BusinessLiveShareRepository.addPhoto` so the client live page
    /// renders the new shot. Returns the storagePath on success.
    func uploadLiveSharePhoto(
        shareId: String,
        photoId: String,
        imageData: Data
    ) async throws -> String {
        let storagePath = "live_walks/\(shareId)/\(photoId).jpg"
        let ref = storage.reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        return storagePath
    }

    // MARK: - Client briefs

    /// Read each booking doc to assemble pre-walk client briefs. Best-
    /// effort: missing fields surface as `nil`; missing bookings drop
    /// out of the result list.
    func loadClientBriefs(bookingIds: [String]) async -> [ClientBrief] {
        guard !bookingIds.isEmpty else { return [] }
        var results: [ClientBrief] = []
        for bookingId in bookingIds {
            do {
                let doc = try await db.collection(Self.collectionBookings)
                    .document(bookingId)
                    .getDocument()
                guard let d = doc.data() else { continue }
                let clientName: String = {
                    let raw = (d["clientName"] as? String) ?? ""
                    return raw.isEmpty ? "Client" : raw
                }()
                let phone = (d["clientPhone"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let address = (d["address"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (d["location"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let keyCode = (d["keyCode"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (d["accessCode"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let instructions = (d["specialInstructions"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (d["specialRequirements"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? (d["notes"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let dogName = (d["dogName"] as? String).flatMap { $0.isEmpty ? nil : $0 }

                results.append(ClientBrief(
                    bookingId: bookingId,
                    clientName: clientName,
                    clientPhone: phone,
                    address: address,
                    keyCode: keyCode,
                    specialInstructions: instructions,
                    dogNames: dogName.map { [$0] } ?? []
                ))
            } catch {
                print("[BusinessWalkSession] loadClientBriefs failed for \(bookingId): \(error)")
            }
        }
        return results
    }

    /// Build per-client share targets for the live-share sheet. Used for
    /// group walks; solo walks use the plain Copy/Send buttons instead.
    func buildBookingShareTargets(
        bookingIds: [String],
        baseUrl: String
    ) async -> [BookingShareTarget] {
        var results: [BookingShareTarget] = []
        for bookingId in bookingIds {
            let separator = baseUrl.contains("?") ? "&" : "?"
            let perClientUrl = "\(baseUrl)\(separator)b=\(bookingId)"
            do {
                let doc = try await db.collection(Self.collectionBookings)
                    .document(bookingId)
                    .getDocument()
                let d = doc.data() ?? [:]
                let rawName = (d["clientName"] as? String) ?? ""
                let clientName = rawName.isEmpty ? "Client" : rawName
                let phone = (d["clientPhone"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                let dogName = (d["dogName"] as? String) ?? ""
                let dogs = dogName.isEmpty ? [] : [dogName]
                results.append(BookingShareTarget(
                    bookingId: bookingId,
                    clientName: clientName,
                    clientPhone: phone,
                    dogNames: dogs,
                    perClientUrl: perClientUrl
                ))
            } catch {
                print("[BusinessWalkSession] buildBookingShareTargets failed for \(bookingId): \(error)")
                results.append(BookingShareTarget(
                    bookingId: bookingId,
                    clientName: "Client",
                    clientPhone: nil,
                    dogNames: [],
                    perClientUrl: perClientUrl
                ))
            }
        }
        return results
    }

    // MARK: - Dog profiles

    /// Read the minimal dog projections needed for the check-in strip.
    /// Field names match the Android `dogs/{id}` schema.
    func loadDogs(dogIds: [String]) async -> [WalkConsoleDog] {
        guard !dogIds.isEmpty else { return [] }
        var results: [WalkConsoleDog] = []
        for dogId in dogIds {
            do {
                let doc = try await db.collection("dogs")
                    .document(dogId)
                    .getDocument()
                guard let d = doc.data() else { continue }
                let name = (d["name"] as? String) ?? "Dog"
                let photoUrl = d["photoUrl"] as? String
                    ?? d["profilePhotoUrl"] as? String
                let breed = d["breed"] as? String
                results.append(WalkConsoleDog(id: dogId, name: name, photoUrl: photoUrl, breed: breed))
            } catch {
                print("[BusinessWalkSession] loadDogs failed for \(dogId): \(error)")
            }
        }
        return results
    }
}
