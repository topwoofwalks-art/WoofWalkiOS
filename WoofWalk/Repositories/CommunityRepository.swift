import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class CommunityRepository {
    static let shared = CommunityRepository()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    private var myCommunitiesListener: ListenerRegistration?

    // MARK: - Discovery

    /// Discover communities with optional filters. Client-side text search since Firestore lacks full-text search.
    func discoverCommunities(
        type: String? = nil,
        privacy: String? = nil,
        searchQuery: String? = nil
    ) async throws -> [Community] {
        var query: Query = db.collection("communities")
            .whereField("isArchived", isEqualTo: false)

        if let type = type {
            query = query.whereField("type", isEqualTo: type)
        }
        if let privacy = privacy {
            query = query.whereField("privacy", isEqualTo: privacy)
        }

        query = query.order(by: "memberCount", descending: true)
            .limit(to: 20)

        let snapshot = try await query.getDocuments()
        var communities = snapshot.documents.compactMap { try? $0.data(as: Community.self) }

        // Client-side text filter
        if let searchQuery = searchQuery, !searchQuery.isEmpty {
            let lower = searchQuery.lowercased()
            communities = communities.filter {
                $0.name.lowercased().contains(lower) ||
                $0.description.lowercased().contains(lower) ||
                $0.tags.contains(where: { $0.lowercased().contains(lower) })
            }
        }

        return communities
    }

    /// Trending communities ordered by member count.
    func getTrendingCommunities() async throws -> [Community] {
        let snapshot = try await db.collection("communities")
            .whereField("isArchived", isEqualTo: false)
            .order(by: "memberCount", descending: true)
            .limit(to: 20)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Community.self) }
    }

    /// Nearby communities using geohash range query with client-side distance filter.
    func getNearbyCommunities(latitude: Double, longitude: Double, radiusKm: Double = 10.0) async throws -> [Community] {
        let geohashRange = GeoHashUtil.getGeohashRange(latitude: latitude, longitude: longitude, radiusKm: radiusKm)

        let snapshot = try await db.collection("communities")
            .whereField("isArchived", isEqualTo: false)
            .whereField("type", isEqualTo: CommunityType.LOCAL_NEIGHBOURHOOD.rawValue)
            .whereField("geohash", isGreaterThanOrEqualTo: geohashRange.lower)
            .whereField("geohash", isLessThanOrEqualTo: geohashRange.upper)
            .limit(to: 50)
            .getDocuments()

        let communities = snapshot.documents.compactMap { try? $0.data(as: Community.self) }
            .filter { community in
                guard let lat = community.latitude, let lon = community.longitude else { return false }
                return GeoHashUtil.distanceInKm(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon) <= radiusKm
            }
            .sorted { $0.memberCount > $1.memberCount }

        return communities
    }

    // MARK: - My Communities (realtime)

    /// Listen to communities the current user belongs to. Returns a Combine publisher.
    func getMyCommunities() -> AnyPublisher<[Community], Never> {
        let subject = CurrentValueSubject<[Community], Never>([])
        guard let uid = auth.currentUser?.uid else {
            return subject.eraseToAnyPublisher()
        }

        myCommunitiesListener?.remove()
        myCommunitiesListener = db.collectionGroup("members")
            .whereField("userId", isEqualTo: uid)
            .whereField("isBanned", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("[CommunityRepository] Error fetching my communities: \(error.localizedDescription)")
                    subject.send([])
                    return
                }

                let communityIds = (snapshot?.documents ?? []).compactMap { doc -> String? in
                    // Path: communities/{communityId}/members/{userId}
                    doc.reference.parent.parent?.documentID
                }

                if communityIds.isEmpty {
                    subject.send([])
                    return
                }

                // Fetch community documents in batches of 10 (Firestore whereIn limit)
                var allCommunities: [Community] = []
                let batches = communityIds.chunked(into: 10)
                let group = DispatchGroup()

                for batch in batches {
                    group.enter()
                    let refs = batch.map { self.db.collection("communities").document($0) }
                    self.db.collection("communities")
                        .whereField(FieldPath.documentID(), in: refs)
                        .getDocuments { communitySnapshot, error in
                            defer { group.leave() }
                            if let error = error {
                                print("[CommunityRepository] Error fetching community batch: \(error.localizedDescription)")
                                return
                            }
                            let communities = (communitySnapshot?.documents ?? [])
                                .compactMap { try? $0.data(as: Community.self) }
                                .filter { !$0.isArchived }
                            allCommunities.append(contentsOf: communities)
                        }
                }

                group.notify(queue: .main) {
                    subject.send(allCommunities)
                }
            }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Single Community

    /// Fetch a single community by ID.
    func getCommunity(id: String) async throws -> Community {
        let doc = try await db.collection("communities").document(id).getDocument()
        guard let community = try? doc.data(as: Community.self) else {
            throw NSError(domain: "CommunityRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Community not found"])
        }
        return community
    }

    // MARK: - CRUD

    /// Create a community and add the current user as OWNER. Returns the new document ID.
    func createCommunity(_ community: Community) async throws -> String {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let userName = auth.currentUser?.displayName ?? "Anonymous"
        let userPhoto = auth.currentUser?.photoURL?.absoluteString

        var data = community
        data.createdBy = uid
        data.creatorName = userName
        data.memberCount = 1
        data.createdAt = Date().timeIntervalSince1970 * 1000
        data.updatedAt = Date().timeIntervalSince1970 * 1000

        if let lat = data.latitude, let lon = data.longitude {
            data.geohash = GeoHashUtil.encode(latitude: lat, longitude: lon, precision: 9)
        }

        let docRef = try db.collection("communities").addDocument(from: data)

        // Add creator as OWNER member
        let member = CommunityMember(
            userId: uid,
            communityId: docRef.documentID,
            displayName: userName,
            photoUrl: userPhoto,
            role: CommunityMemberRole.OWNER.rawValue
        )
        try db.collection("communities").document(docRef.documentID)
            .collection("members").document(uid)
            .setData(from: member)

        print("[CommunityRepository] Community created: \(docRef.documentID)")
        return docRef.documentID
    }

    /// Update an existing community. Caller must be owner or admin.
    func updateCommunity(_ community: Community) async throws {
        guard let communityId = community.id else {
            throw NSError(domain: "CommunityRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Community ID is required"])
        }
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let existing = try await getCommunity(id: communityId)
        if existing.createdBy != uid {
            let memberDoc = try await db.collection("communities").document(communityId)
                .collection("members").document(uid).getDocument()
            if let member = try? memberDoc.data(as: CommunityMember.self), !member.canAdmin() {
                throw NSError(domain: "CommunityRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to update this community"])
            }
        }

        var updated = community
        updated.updatedAt = Date().timeIntervalSince1970 * 1000
        try db.collection("communities").document(communityId).setData(from: updated, merge: true)
        print("[CommunityRepository] Community updated: \(communityId)")
    }

    /// Delete a community. Only the owner can delete.
    func deleteCommunity(id: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let community = try await getCommunity(id: id)
        if community.createdBy != uid {
            throw NSError(domain: "CommunityRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this community"])
        }

        try await db.collection("communities").document(id).delete()
        print("[CommunityRepository] Community deleted: \(id)")
    }

    // MARK: - Join / Leave

    /// Join a public community. Uses a transaction to atomically add member and increment count.
    func joinCommunity(id: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let userName = auth.currentUser?.displayName ?? "Anonymous"
        let userPhoto = auth.currentUser?.photoURL?.absoluteString

        let community = try await getCommunity(id: id)

        if community.requiresInvite() {
            throw NSError(domain: "CommunityRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "This community requires an invitation to join"])
        }
        if community.getCommunityPrivacy() == .PRIVATE {
            throw NSError(domain: "CommunityRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "This community requires approval to join"])
        }

        let memberRef = db.collection("communities").document(id)
            .collection("members").document(uid)
        let existing = try await memberRef.getDocument()
        if existing.exists {
            throw NSError(domain: "CommunityRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Already a member of this community"])
        }

        let member = CommunityMember(
            userId: uid,
            communityId: id,
            displayName: userName,
            photoUrl: userPhoto,
            role: CommunityMemberRole.MEMBER.rawValue
        )

        let communityRef = db.collection("communities").document(id)
        try await db.runTransaction { transaction, errorPointer in
            do {
                try transaction.setData(from: member, forDocument: memberRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            transaction.updateData([
                "memberCount": FieldValue.increment(Int64(1)),
                "updatedAt": Date().timeIntervalSince1970 * 1000
            ], forDocument: communityRef)
            return nil
        }

        print("[CommunityRepository] Joined community: \(id)")
    }

    /// Leave a community. Owners cannot leave without transferring ownership first.
    func leaveCommunity(id: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let memberRef = db.collection("communities").document(id)
            .collection("members").document(uid)
        let memberDoc = try await memberRef.getDocument()
        guard let member = try? memberDoc.data(as: CommunityMember.self) else {
            throw NSError(domain: "CommunityRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not a member of this community"])
        }

        if member.isOwner() {
            throw NSError(domain: "CommunityRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Owner cannot leave community. Transfer ownership first."])
        }

        let communityRef = db.collection("communities").document(id)
        try await db.runTransaction { transaction, errorPointer in
            transaction.deleteDocument(memberRef)
            transaction.updateData([
                "memberCount": FieldValue.increment(Int64(-1)),
                "updatedAt": Date().timeIntervalSince1970 * 1000
            ], forDocument: communityRef)
            return nil
        }

        print("[CommunityRepository] Left community: \(id)")
    }

    // MARK: - Members

    /// Fetch members of a community.
    func getMembers(communityId: String) async throws -> [CommunityMember] {
        let snapshot = try await db.collection("communities").document(communityId)
            .collection("members")
            .order(by: "joinedAt", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CommunityMember.self) }
    }

    /// Update a member's role. Caller must be owner or admin.
    func updateMemberRole(communityId: String, userId: String, role: CommunityMemberRole) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Verify caller has admin privileges
        let callerDoc = try await db.collection("communities").document(communityId)
            .collection("members").document(uid).getDocument()
        guard let caller = try? callerDoc.data(as: CommunityMember.self), caller.canAdmin() else {
            throw NSError(domain: "CommunityRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to change member roles"])
        }

        try await db.collection("communities").document(communityId)
            .collection("members").document(userId)
            .updateData([
                "role": role.rawValue,
                "lastActiveAt": Date().timeIntervalSince1970 * 1000
            ])
        print("[CommunityRepository] Updated role for \(userId) to \(role.rawValue) in \(communityId)")
    }

    /// Remove a member from the community. Caller must be owner or admin.
    func kickMember(communityId: String, userId: String) async throws {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "CommunityRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Verify caller has admin privileges
        let callerDoc = try await db.collection("communities").document(communityId)
            .collection("members").document(uid).getDocument()
        guard let caller = try? callerDoc.data(as: CommunityMember.self), caller.canAdmin() else {
            throw NSError(domain: "CommunityRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to kick members"])
        }

        // Cannot kick the owner
        let targetDoc = try await db.collection("communities").document(communityId)
            .collection("members").document(userId).getDocument()
        if let target = try? targetDoc.data(as: CommunityMember.self), target.isOwner() {
            throw NSError(domain: "CommunityRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot kick the community owner"])
        }

        let memberRef = db.collection("communities").document(communityId)
            .collection("members").document(userId)
        let communityRef = db.collection("communities").document(communityId)

        try await db.runTransaction { transaction, errorPointer in
            transaction.deleteDocument(memberRef)
            transaction.updateData([
                "memberCount": FieldValue.increment(Int64(-1)),
                "updatedAt": Date().timeIntervalSince1970 * 1000
            ], forDocument: communityRef)
            return nil
        }

        print("[CommunityRepository] Kicked \(userId) from \(communityId)")
    }

    // MARK: - Cleanup

    func stopListening() {
        myCommunitiesListener?.remove()
        myCommunitiesListener = nil
    }

    deinit {
        myCommunitiesListener?.remove()
    }
}

// MARK: - Array Chunking Helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - GeoHash Utilities

/// Minimal geohash utilities for nearby community queries.
/// Matches Android GeoHashUtil used in CommunityRepository.
struct GeoHashUtil {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(latitude: Double, longitude: Double, precision: Int) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var hash = ""
        var isEven = true
        var bit = 0
        var ch = 0

        while hash.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    ch |= (1 << (4 - bit))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    ch |= (1 << (4 - bit))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            isEven.toggle()
            bit += 1
            if bit == 5 {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }
        return hash
    }

    static func getGeohashRange(latitude: Double, longitude: Double, radiusKm: Double) -> (lower: String, upper: String) {
        let precision = 5
        let hash = encode(latitude: latitude, longitude: longitude, precision: precision)
        // Simple range: use geohash prefix as lower bound, increment last char for upper
        var upper = hash
        if let lastChar = upper.last, let idx = base32.firstIndex(of: lastChar), idx < base32.count - 1 {
            upper = String(upper.dropLast()) + String(base32[idx + 1])
        }
        return (hash, upper)
    }

    static func distanceInKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0 // Earth radius in km
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
