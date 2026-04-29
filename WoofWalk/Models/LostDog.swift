import Foundation
import FirebaseFirestore

/// Mirrors the canonical Android model in
/// `app/src/main/java/com/woofwalk/data/model/LostDog.kt`. Collection
/// name on Firestore is `lost_dog_alerts` (Android wrote this name
/// before iOS port; rules at firestore.rules:3908 grant read to any
/// authenticated user, write to the reporter only).
///
/// `id` is plain optional (not `@DocumentID`) — the wrapper requires
/// FirebaseFirestoreSwift and complicates manual struct
/// initialization. The repository populates `id` from
/// `doc.documentID` after decoding.
struct LostDog: Identifiable, Codable {
    var id: String?

    var dogId: String
    var dogName: String
    var dogPhotoUrl: String?
    var dogBreed: String

    var reportedBy: String          // user uid
    var reporterName: String
    var reporterPhone: String?

    var lat: Double
    var lng: Double
    var geohash: String              // 7-char geohash for radius queries
    var locationDescription: String
    var description: String

    /// "LOST" or "FOUND" — string keeps wire-compatibility with the
    /// Kotlin enum.
    var status: String

    var reportedAt: Timestamp?
    var foundAt: Timestamp?
    var expiresAt: Timestamp?
    var alertRadiusKm: Double = 5.0

    /// Helper — true when the alert is still LOST and not past expiry.
    var isActive: Bool {
        guard status == "LOST" else { return false }
        if let expiry = expiresAt?.dateValue(), expiry < Date() { return false }
        return true
    }

    // Keep `id` out of the Firestore wire payload — it lives in the
    // doc id, not as a field. Without this, `setData(from:)` would
    // round-trip `id: null` into the doc body.
    enum CodingKeys: String, CodingKey {
        case dogId
        case dogName
        case dogPhotoUrl
        case dogBreed
        case reportedBy
        case reporterName
        case reporterPhone
        case lat
        case lng
        case geohash
        case locationDescription
        case description
        case status
        case reportedAt
        case foundAt
        case expiresAt
        case alertRadiusKm
    }
}

enum LostDogStatus: String {
    case lost = "LOST"
    case found = "FOUND"
}
