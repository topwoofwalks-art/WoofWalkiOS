import Foundation
import FirebaseFirestore

// MARK: - Meet & Greet Models
//
// Mirrors the `meet_greet_threads/{threadId}` doc shape written by the
// `meetGreet` Cloud Functions module
// (`functions/src/meetGreet/meetGreet.ts`).
//
// Privacy ladder — see CF header comment for the trust progression.
// The exact provider address only lands in `exactAddress` once both
// sides confirm the meet time (`exactAddressRevealed = true`).
//
// All field names match the CF write payload 1:1 so a Codable decode
// of the Firestore doc Just Works.

/// Meet & Greet thread status. Raw values match the strings written
/// by the CF; do not rename without bumping the wire contract.
enum MGStatus: String, Codable {
    case pendingProviderResponse = "pending_provider_response"
    case inConversation = "in_conversation"
    case timeProposed = "time_proposed"
    case confirmed = "confirmed"
    case completed = "completed"
    case cancelled = "cancelled"

    /// Human-readable pill label (drives the chat-thread status pill).
    var displayLabel: String {
        switch self {
        case .pendingProviderResponse: return "Awaiting reply"
        case .inConversation: return "In conversation"
        case .timeProposed: return "Time suggested"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    /// True for any open / actionable status; closed statuses
    /// (cancelled, completed) hide most CTAs.
    var isOpen: Bool {
        self != .cancelled && self != .completed
    }
}

/// Proposed / confirmed time for the meet. `locationLabel` is a
/// public-friendly name like "Crook town park" — never the full
/// address (that's gated behind `exactAddressRevealed`).
struct MGTime: Codable, Hashable {
    var startMs: Int64
    var durationMin: Int
    var locationLabel: String

    /// Decoded `startMs` as a Date for SwiftUI date formatters.
    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startMs) / 1000.0)
    }
}

/// Top-level thread doc. Decoded with Firestore's `data(as:)`.
struct MeetGreetThread: Identifiable, Codable {
    @DocumentID var docId: String?

    /// Server-written `id` field (mirrors the doc id). Use this rather
    /// than `docId` for stable referencing through CF calls — CF reads
    /// it from the request payload.
    var id: String

    var clientUid: String
    var providerOrgId: String

    // Dog projection — captured at request time so the provider can
    // see who they'd be meeting before the client edits their dog
    // profile later.
    var clientDogId: String
    var clientDogName: String
    var clientDogBreed: String?

    var introMessage: String
    var roughArea: String

    var status: MGStatus
    var proposedTime: MGTime?
    var confirmedTime: MGTime?
    var proposedByUid: String?
    var confirmedByUid: String?
    var confirmedAt: Int64?

    /// Privacy gate. Only `true` once a time is confirmed by the side
    /// that didn't propose it; before that, the client never sees the
    /// provider's exact street address.
    var exactAddressRevealed: Bool
    var exactAddress: String?
    var providerPhone: String?
    var providerEmail: String?

    /// Display-name projections from the CF — short forms only
    /// (client = first name, provider = "Sarah K.") so neither side
    /// gets the other's full identity before they meet.
    var clientDisplayName: String
    var providerDisplayName: String
    var providerLogoUrl: String?
    var providerOrgName: String

    var createdAt: Int64
    var updatedAt: Int64
    var lastMessageAt: Int64

    var cancelledByUid: String?
    var cancelledReason: String?
    var cancelledAt: Int64?
    var completedByUid: String?
    var completedAt: Int64?

    /// Convenience — the side viewing the thread.
    enum Viewer { case client, provider, unknown }
    func viewer(currentUid: String?) -> Viewer {
        guard let uid = currentUid else { return .unknown }
        return uid == clientUid ? .client : .provider
    }
}

/// Sub-collection message. `kind` discriminates between plain text
/// and the embedded action cards (`time_proposal`, `time_confirmation`)
/// that the CF writes inline so the chat UI shows them as a single
/// timeline rather than mixing in out-of-band UI state.
struct MeetGreetMessage: Identifiable, Codable {
    @DocumentID var id: String?

    var senderUid: String
    /// "client" or "provider" — the CF writes one of these two.
    var senderRole: String
    var text: String
    var kind: String   // "text" | "time_proposal" | "time_confirmation"
    var createdAt: Int64

    /// Populated only on `kind == "time_proposal"`.
    var proposedTime: MGTime?
    /// Populated only on `kind == "time_confirmation"`.
    var confirmedTime: MGTime?

    /// Decoded `createdAt` as Date.
    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0)
    }

    enum Kind: String {
        case text
        case timeProposal = "time_proposal"
        case timeConfirmation = "time_confirmation"
    }

    var messageKind: Kind { Kind(rawValue: kind) ?? .text }
}
