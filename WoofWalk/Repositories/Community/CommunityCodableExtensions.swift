import Foundation
import FirebaseFirestore

/// Helpers for decoding Firestore docs into Community feature models.
/// Each model uses a plain `id: String?` (not `@DocumentID`) — see
/// Community.swift for the reasoning. These helpers populate `id` from
/// `documentID` after the throwing `data(as:)` call so callers don't have
/// to remember the manual step everywhere.
extension DocumentSnapshot {
    func decodeCommunity() -> Community? {
        var c = try? data(as: Community.self)
        if c?.id == nil { c?.id = documentID }
        return c
    }

    func decodeCommunityPost() -> CommunityPost? {
        var p = try? data(as: CommunityPost.self)
        if p?.id == nil { p?.id = documentID }
        return p
    }

    func decodeCommunityMember() -> CommunityMember? {
        var m = try? data(as: CommunityMember.self)
        if m?.id == nil { m?.id = documentID }
        if m?.userId.isEmpty ?? true { m?.userId = documentID }
        return m
    }

    func decodeCommunityComment() -> CommunityComment? {
        var c = try? data(as: CommunityComment.self)
        if c?.id == nil { c?.id = documentID }
        return c
    }

    func decodeCommunityEvent() -> CommunityEvent? {
        var e = try? data(as: CommunityEvent.self)
        if e?.id == nil { e?.id = documentID }
        return e
    }

    func decodeCommunityJoinRequest() -> CommunityJoinRequest? {
        var r = try? data(as: CommunityJoinRequest.self)
        if r?.id == nil { r?.id = documentID }
        return r
    }

    func decodeCommunityReport() -> CommunityReport? {
        var r = try? data(as: CommunityReport.self)
        if r?.id == nil { r?.id = documentID }
        return r
    }

    func decodeCommunityChatMessage() -> CommunityChatMessage? {
        var m = try? data(as: CommunityChatMessage.self)
        if m?.id == nil { m?.id = documentID }
        return m
    }
}

extension QueryDocumentSnapshot {
    func decodeCommunity() -> Community? { (self as DocumentSnapshot).decodeCommunity() }
    func decodeCommunityPost() -> CommunityPost? { (self as DocumentSnapshot).decodeCommunityPost() }
    func decodeCommunityMember() -> CommunityMember? { (self as DocumentSnapshot).decodeCommunityMember() }
    func decodeCommunityComment() -> CommunityComment? { (self as DocumentSnapshot).decodeCommunityComment() }
    func decodeCommunityEvent() -> CommunityEvent? { (self as DocumentSnapshot).decodeCommunityEvent() }
    func decodeCommunityJoinRequest() -> CommunityJoinRequest? { (self as DocumentSnapshot).decodeCommunityJoinRequest() }
    func decodeCommunityReport() -> CommunityReport? { (self as DocumentSnapshot).decodeCommunityReport() }
    func decodeCommunityChatMessage() -> CommunityChatMessage? { (self as DocumentSnapshot).decodeCommunityChatMessage() }
}
