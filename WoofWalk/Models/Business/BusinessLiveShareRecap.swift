import Foundation

// MARK: - Business Live-Walk Recap Models
//
// Client-side projection of `live_share_links/{shareId}` for the
// post-walk recap surface. Phase 5 — surfaces the walker's photos,
// note, and branded close-out for the household whose booking the
// client is viewing.
//
// The walker's app already writes everything we read here via the
// `createBusinessLiveShare` / `pushBusinessLiveLocation` /
// `addBusinessLiveSharePhoto` / `endBusinessLiveShare` callables.
// The Firestore rule on /live_share_links allows authenticated
// reads, so the client app fetches by `participantBookingIds`
// without a CF round trip.

/// One recap photo. Mirrors the `photos` subcollection doc shape.
struct BusinessLiveSharePhoto: Identifiable, Equatable {
    let id: String
    /// Direct download URL (composed by the CF at write time).
    let storageUrl: String
    /// Optional thumbnail; falls back to `storageUrl` when absent.
    let thumbnailUrl: String?
    let caption: String?
    let takenAt: Int64
    let lat: Double?
    let lng: Double?
}

/// One participating household's projected dog list for the recap.
struct BusinessLiveShareParticipant: Equatable {
    let bookingId: String
    let clientName: String?
    let dogs: [BusinessLiveShareDog]
}

/// Public-safe dog projection — name + photo only.
struct BusinessLiveShareDog: Identifiable, Equatable {
    let id: String
    let name: String
    let photoUrl: String?
}

/// Full recap doc the client renders. Built by the repository from
/// the `live_share_links/{id}` doc + the `photos` subcollection,
/// filtered to the viewer's own booking so a client can't see
/// other households' dogs even if a stale doc leaked the wider
/// participant list (privacy parity with the public-portal's
/// per-viewer filter in `getBusinessLiveShareByToken`).
struct BusinessLiveShareRecap: Equatable {
    let id: String
    let walkSessionId: String?
    let walkEnded: Bool
    let walkerNote: String?
    let walkerNoteUpdatedAt: Int64?
    let lastUpdatedAt: Int64?
    let scheduledEndAt: Int64?
    let distanceMeters: Double
    let durationSec: Int64
    let walkerDisplayName: String?
    let walkerPhotoUrl: String?
    let orgId: String?
    let orgName: String?
    let orgLogoUrl: String?
    /// Hex string ("#RRGGBB") if the org carries a brand colour;
    /// otherwise `nil` and the recap falls back to the app accent.
    let orgBrandColour: String?
    let participants: [BusinessLiveShareParticipant]
    let photos: [BusinessLiveSharePhoto]

    /// First dog from the viewer's participant entry — drives the
    /// "🏡 {dogName} is home" hero copy. Solo walks return the
    /// single dog; group-walk recaps return the viewer-household's
    /// dog because `participants` was filtered to that booking.
    var primaryDogName: String? {
        participants.first?.dogs.first?.name
    }

    /// Has any human-rendered content for the recap surface? Used to
    /// short-circuit rendering when the share doc exists but has no
    /// photos / note (treat as "no recap to show").
    var hasContent: Bool {
        !photos.isEmpty || (walkerNote?.isEmpty == false)
    }
}
