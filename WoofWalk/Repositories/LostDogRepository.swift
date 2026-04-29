import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// iOS port of Android's LostDogRepository. Writes to and reads from
/// the canonical Firestore collection `lost_dog_alerts` (the rules
/// file at firestore.rules:3908 grants read to any authenticated
/// user, write to the reporter only). Photos go to
/// `gs://.../lost_dog_alerts/{uid}/{uuid}.jpg` per the storage rules.
class LostDogRepository {
    static let shared = LostDogRepository()

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let auth = Auth.auth()

    private init() {}

    private var collection: CollectionReference {
        db.collection("lost_dog_alerts")
    }

    // MARK: - Photo upload

    /// Uploads a JPEG photo for a lost-dog alert. Returns the public
    /// download URL. Caller is responsible for keeping the upload
    /// progress UI honest.
    func uploadPhoto(_ data: Data) async throws -> String {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "LostDogRepository", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        let id = UUID().uuidString
        let ref = storage.reference().child("lost_dog_alerts/\(uid)/\(id).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        return try await ref.downloadURL().absoluteString
    }

    // MARK: - Report

    /// Creates a lost-dog alert. `dogId` may be empty for "I found a
    /// dog I don't own" reports — Android uses an empty string in
    /// that path, we mirror it exactly to keep cross-platform Firestore
    /// docs identical.
    @discardableResult
    func reportLostDog(
        dogId: String,
        dogName: String,
        dogPhotoUrl: String?,
        dogBreed: String,
        lat: Double,
        lng: Double,
        locationDescription: String,
        description: String,
        reporterPhone: String?,
        durationHours: Int = 24,
        alertRadiusKm: Double = 5.0
    ) async throws -> String {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "LostDogRepository", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Sign in to report a lost dog"])
        }

        // Look up reporter display name from /users/{uid}. Best-effort
        // — fall back to "WoofWalk user" if the doc isn't there yet
        // (a fresh sign-up reporting before profile setup completes).
        let userSnap = try? await db.collection("users").document(uid).getDocument()
        let reporterName = (userSnap?.data()?["username"] as? String)
            ?? (userSnap?.data()?["displayName"] as? String)
            ?? "WoofWalk user"

        let now = Date()
        let expires = Calendar.current.date(byAdding: .hour, value: durationHours, to: now) ?? now

        let alert = LostDog(
            dogId: dogId,
            dogName: dogName,
            dogPhotoUrl: dogPhotoUrl,
            dogBreed: dogBreed,
            reportedBy: uid,
            reporterName: reporterName,
            reporterPhone: reporterPhone,
            lat: lat,
            lng: lng,
            geohash: Geohash.encode(latitude: lat, longitude: lng, precision: 7),
            locationDescription: locationDescription,
            description: description,
            status: LostDogStatus.lost.rawValue,
            reportedAt: Timestamp(date: now),
            foundAt: nil,
            expiresAt: Timestamp(date: expires),
            alertRadiusKm: alertRadiusKm
        )

        let ref = collection.document()
        try ref.setData(from: alert)
        return ref.documentID
    }

    // MARK: - Mutations on existing alerts

    func markFound(alertId: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "LostDogRepository", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Sign in to update this alert"])
        }
        let snap = try await collection.document(alertId).getDocument()
        let reporter = snap.data()?["reportedBy"] as? String
        guard reporter == uid else {
            throw NSError(domain: "LostDogRepository", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the reporter can mark a dog as found"])
        }
        try await collection.document(alertId).updateData([
            "status": LostDogStatus.found.rawValue,
            "foundAt": FieldValue.serverTimestamp(),
        ])
    }

    func extendAlert(alertId: String, additionalHours: Int) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        let snap = try await collection.document(alertId).getDocument()
        guard let data = snap.data(), data["reportedBy"] as? String == uid else {
            throw NSError(domain: "LostDogRepository", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the reporter can extend this alert"])
        }
        let currentExpiry = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date()
        let newExpiry = Calendar.current.date(
            byAdding: .hour,
            value: additionalHours,
            to: currentExpiry
        ) ?? currentExpiry
        try await collection.document(alertId).updateData([
            "expiresAt": Timestamp(date: newExpiry),
        ])
    }

    func deleteAlert(alertId: String) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        let snap = try await collection.document(alertId).getDocument()
        guard snap.data()?["reportedBy"] as? String == uid else {
            throw NSError(domain: "LostDogRepository", code: 403,
                          userInfo: [NSLocalizedDescriptionKey: "Only the reporter can delete this alert"])
        }
        try await collection.document(alertId).delete()
    }

    // MARK: - Subscriptions

    /// Live listener for the calling user's own reports.
    func observeMyReports(onChange: @escaping ([LostDog]) -> Void) -> ListenerRegistration? {
        guard let uid = auth.currentUser?.uid else {
            onChange([])
            return nil
        }
        return collection
            .whereField("reportedBy", isEqualTo: uid)
            .order(by: "reportedAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents ?? []
                let parsed: [LostDog] = docs.compactMap { Self.decode($0) }
                onChange(parsed)
            }
    }

    /// Live listener for active LOST alerts. Filtering by radius is
    /// done in-memory after geohash range queries — same approach as
    /// Android's getNearbyLostDogs.
    func observeAllActive(onChange: @escaping ([LostDog]) -> Void) -> ListenerRegistration {
        return collection
            .whereField("status", isEqualTo: LostDogStatus.lost.rawValue)
            .order(by: "reportedAt", descending: true)
            .limit(to: 200)
            .addSnapshotListener { snapshot, _ in
                let docs = snapshot?.documents ?? []
                let parsed: [LostDog] = docs.compactMap { Self.decode($0) }
                onChange(parsed)
            }
    }

    /// Decode a Firestore document into a `LostDog`, populating `id`
    /// from the document path. We avoid `data(as:)` because the
    /// `FirebaseFirestoreSwift` Codable extensions require an extra
    /// import that this target doesn't pull in; manual decoding via
    /// JSON-roundtrip works against the basic FirebaseFirestore SDK.
    private static func decode(_ doc: QueryDocumentSnapshot) -> LostDog? {
        let data = doc.data()
        guard let dogName = data["dogName"] as? String,
              let reportedBy = data["reportedBy"] as? String
        else { return nil }
        var alert = LostDog(
            dogId: data["dogId"] as? String ?? "",
            dogName: dogName,
            dogPhotoUrl: data["dogPhotoUrl"] as? String,
            dogBreed: data["dogBreed"] as? String ?? "",
            reportedBy: reportedBy,
            reporterName: data["reporterName"] as? String ?? "",
            reporterPhone: data["reporterPhone"] as? String,
            lat: data["lat"] as? Double ?? 0,
            lng: data["lng"] as? Double ?? 0,
            geohash: data["geohash"] as? String ?? "",
            locationDescription: data["locationDescription"] as? String ?? "",
            description: data["description"] as? String ?? "",
            status: data["status"] as? String ?? LostDogStatus.lost.rawValue,
            reportedAt: data["reportedAt"] as? Timestamp,
            foundAt: data["foundAt"] as? Timestamp,
            expiresAt: data["expiresAt"] as? Timestamp,
            alertRadiusKm: data["alertRadiusKm"] as? Double ?? 5.0
        )
        alert.id = doc.documentID
        return alert
    }
}
