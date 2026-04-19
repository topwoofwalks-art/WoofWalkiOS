import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import CoreLocation
import Combine

enum FeedMode: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case nearby = "Nearby"
    case following = "Following"

    var id: String { rawValue }
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var selectedPost: Post?
    @Published var feedMode: FeedMode = .forYou

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?

    // MARK: - Pagination

    private let pageSize = 20
    private var lastDocument: DocumentSnapshot?
    private var hasMorePages = true

    // MARK: - Social Graph Cache

    private var friendIds: Set<String> = []
    private var followingIds: Set<String> = []
    private var socialGraphCachedAt: Date = .distantPast
    private let socialGraphTTL: TimeInterval = 300 // 5 minutes
    private var socialGraphLoading = false

    // Anti-spam: link detection (mirrors Android FeedRepository.LINK_PATTERN)
    private static let linkPattern = try! NSRegularExpression(
        pattern: #"(https?://|www\.|[a-zA-Z0-9-]+\.(com|co\.uk|org|net|io|app|dev|me|uk|info|biz|shop|store)(/\S*)?)"#,
        options: .caseInsensitive
    )

    // MARK: - Location

    private var locationCancellable: AnyCancellable?

    init() {
        loadSocialGraph()
        loadPosts()
        observeLocation()
    }

    // MARK: - Location Observation

    private func observeLocation() {
        locationCancellable = LocationService.shared.$currentLocation
            .compactMap { $0 }
            .removeDuplicates { lhs, rhs in
                abs(lhs.latitude - rhs.latitude) < 0.001 && abs(lhs.longitude - rhs.longitude) < 0.001
            }
            .sink { [weak self] _ in
                guard let self else { return }
                // If user is on Nearby tab and we got a location update, reload
                if self.feedMode == .nearby {
                    self.listener?.remove()
                    self.resetPagination()
                    self.loadPosts()
                }
            }
    }

    // MARK: - Social Graph

    /// Load friend IDs (from "friendships" collection) and following IDs (from "followers" collection).
    /// Cached for 5 minutes to avoid hammering Firestore on every tab switch.
    private func loadSocialGraph(force: Bool = false) {
        guard let uid = auth.currentUser?.uid else { return }
        if !force && Date().timeIntervalSince(socialGraphCachedAt) < socialGraphTTL { return }
        if socialGraphLoading { return }
        socialGraphLoading = true

        Task {
            async let friendsResult = loadFriendIds(userId: uid)
            async let followingResult = loadFollowingIds(userId: uid)

            let (friends, following) = await (friendsResult, followingResult)
            self.friendIds = friends
            self.followingIds = following
            self.socialGraphCachedAt = Date()
            self.socialGraphLoading = false
            print("[Feed] Social graph cached: \(friends.count) friends, \(following.count) following")

            // If currently on Following tab, reload with the new social graph
            if self.feedMode == .following && !self.posts.isEmpty {
                self.listener?.remove()
                self.resetPagination()
                self.loadPosts()
            }
        }
    }

    /// Query "friendships" collection for accepted friendships where this user is userId1 or userId2.
    /// Matches Android FriendRepository.getFriendsList() structure.
    private func loadFriendIds(userId: String) async -> Set<String> {
        var ids = Set<String>()
        do {
            // Where current user is userId1
            let snapshot1 = try await db.collection("friendships")
                .whereField("userId1", isEqualTo: userId)
                .whereField("status", isEqualTo: "ACCEPTED")
                .getDocuments()
            for doc in snapshot1.documents {
                if let id2 = doc.data()["userId2"] as? String { ids.insert(id2) }
            }

            // Where current user is userId2
            let snapshot2 = try await db.collection("friendships")
                .whereField("userId2", isEqualTo: userId)
                .whereField("status", isEqualTo: "ACCEPTED")
                .getDocuments()
            for doc in snapshot2.documents {
                if let id1 = doc.data()["userId1"] as? String { ids.insert(id1) }
            }
        } catch {
            print("[Feed] Failed to load friend IDs: \(error.localizedDescription)")
        }
        return ids
    }

    /// Query "followers" collection where followerId == userId to get who this user follows.
    /// Mirrors the Android UserRepository.getFollowing() logic.
    private func loadFollowingIds(userId: String) async -> Set<String> {
        do {
            let snapshot = try await db.collection("followers")
                .whereField("followerId", isEqualTo: userId)
                .getDocuments()

            var ids = Set<String>()
            for doc in snapshot.documents {
                if let followingId = doc.data()["followingId"] as? String {
                    ids.insert(followingId)
                }
            }
            return ids
        } catch {
            print("[Feed] Failed to load following IDs: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Feed Mode

    func switchMode(_ mode: FeedMode) {
        guard mode != feedMode else { return }
        feedMode = mode
        listener?.remove()
        resetPagination()
        posts = []
        loadPosts()
    }

    private func resetPagination() {
        lastDocument = nil
        hasMorePages = true
    }

    // MARK: - Loading

    func loadPosts() {
        guard !isLoading else { return }
        isLoading = true

        switch feedMode {
        case .forYou:
            loadForYouPosts()
        case .nearby:
            loadNearbyPosts()
        case .following:
            loadFollowingPosts()
        }
    }

    /// Load more posts for infinite scroll (all modes use one-shot get, not listener).
    func loadMorePosts() {
        guard !isLoading && !isLoadingMore && hasMorePages else { return }
        isLoadingMore = true

        Task {
            switch feedMode {
            case .forYou:
                await loadMoreForYou()
            case .nearby:
                await loadMoreNearby()
            case .following:
                await loadMoreFollowing()
            }
            isLoadingMore = false
        }
    }

    // MARK: - For You

    /// For You: all posts sorted by recency, using snapshot listener for real-time updates on first page.
    private func loadForYouPosts() {
        let query: Query = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            self.isLoading = false

            if let error {
                let nsError = error as NSError
                if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                    print("[Feed] Index missing, falling back to client-side sort")
                    self.loadPostsUnsorted()
                } else {
                    print("[Feed] Snapshot error: \(error.localizedDescription)")
                }
                return
            }

            guard let documents = snapshot?.documents else {
                self.posts = []
                return
            }

            self.posts = documents.compactMap { try? $0.data(as: Post.self) }
            self.lastDocument = documents.last
            self.hasMorePages = documents.count >= self.pageSize
        }
    }

    private func loadMoreForYou() async {
        guard let lastDoc = lastDocument else {
            hasMorePages = false
            return
        }

        do {
            let snapshot = try await db.collection("posts")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
                .start(afterDocument: lastDoc)
                .getDocuments()

            let newPosts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
            let existingIds = Set(posts.compactMap { $0.id })
            let deduplicated = newPosts.filter { $0.id != nil && !existingIds.contains($0.id!) }

            posts.append(contentsOf: deduplicated)
            lastDocument = snapshot.documents.last
            hasMorePages = snapshot.documents.count >= pageSize
        } catch {
            print("[Feed] Error loading more For You posts: \(error.localizedDescription)")
        }
    }

    // MARK: - Nearby

    /// Nearby: filter posts within 25km of user location.
    /// Uses geohash range query when available, otherwise falls back to fetching + client-side distance filter.
    private func loadNearbyPosts() {
        guard let coord = LocationService.shared.currentLocation else {
            // No location yet -- show empty state, will reload when location arrives
            isLoading = false
            posts = []
            print("[Feed] Nearby: no location available yet")
            return
        }

        let userLat = coord.latitude
        let userLng = coord.longitude

        // Fetch a larger batch and filter by distance client-side.
        // Posts without lat/lng are excluded.
        listener?.remove()

        Task {
            do {
                let snapshot = try await db.collection("posts")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 100)
                    .getDocuments()

                let allPosts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
                let nearbyPosts = allPosts.filter { post in
                    guard let lat = post.latitude, let lng = post.longitude else { return false }
                    return Self.haversineDistanceKm(lat1: userLat, lon1: userLng, lat2: lat, lon2: lng) <= 25.0
                }
                .sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }

                self.posts = Array(nearbyPosts.prefix(pageSize))
                self.lastDocument = nil // Nearby uses client-side filtering, pagination handled differently
                self.hasMorePages = nearbyPosts.count > pageSize
                self.isLoading = false
            } catch {
                print("[Feed] Nearby error: \(error.localizedDescription)")
                self.isLoading = false
            }
        }
    }

    private func loadMoreNearby() async {
        guard let coord = LocationService.shared.currentLocation else { return }
        let userLat = coord.latitude
        let userLng = coord.longitude

        // For nearby, we already fetched a larger batch. Load next batch from Firestore.
        do {
            let currentCount = posts.count
            let snapshot = try await db.collection("posts")
                .order(by: "createdAt", descending: true)
                .limit(to: 200)
                .getDocuments()

            let allPosts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
            let existingIds = Set(posts.compactMap { $0.id })
            let nearbyPosts = allPosts.filter { post in
                guard let id = post.id, !existingIds.contains(id) else { return false }
                guard let lat = post.latitude, let lng = post.longitude else { return false }
                return Self.haversineDistanceKm(lat1: userLat, lon1: userLng, lat2: lat, lon2: lng) <= 25.0
            }
            .sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }

            let nextPage = Array(nearbyPosts.prefix(pageSize))
            posts.append(contentsOf: nextPage)
            hasMorePages = !nextPage.isEmpty
        } catch {
            print("[Feed] Nearby loadMore error: \(error.localizedDescription)")
        }
    }

    // MARK: - Following

    /// Following: only posts from friends and followed users, sorted by recency.
    private func loadFollowingPosts() {
        guard let uid = auth.currentUser?.uid else {
            isLoading = false
            posts = []
            return
        }

        let socialIds = Array(friendIds.union(followingIds).union([uid]))

        if socialIds.count <= 1 {
            // Only self -- show own posts or empty state
            isLoading = false
            loadFollowingPostsForIds([uid])
            return
        }

        loadFollowingPostsForIds(socialIds)
    }

    /// Firestore `whereField(in:)` supports max 30 values. Chunk and merge.
    private func loadFollowingPostsForIds(_ ids: [String]) {
        let chunks = ids.chunked(into: 30)

        Task {
            var allPosts: [Post] = []

            for chunk in chunks {
                do {
                    let snapshot = try await db.collection("posts")
                        .whereField("authorId", in: chunk)
                        .order(by: "createdAt", descending: true)
                        .limit(to: pageSize)
                        .getDocuments()

                    let chunkPosts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
                    allPosts.append(contentsOf: chunkPosts)

                    // Track last document for pagination (use last chunk's last doc)
                    if let lastDoc = snapshot.documents.last {
                        self.lastDocument = lastDoc
                    }
                } catch {
                    let nsError = error as NSError
                    if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                        // Index missing -- fallback: fetch without ordering, sort client-side
                        print("[Feed] Following index missing, falling back to client-side sort")
                        do {
                            let snapshot = try await db.collection("posts")
                                .whereField("authorId", in: chunk)
                                .limit(to: pageSize)
                                .getDocuments()
                            let chunkPosts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
                            allPosts.append(contentsOf: chunkPosts)
                        } catch {
                            print("[Feed] Following fallback error: \(error.localizedDescription)")
                        }
                    } else {
                        print("[Feed] Following error: \(error.localizedDescription)")
                    }
                }
            }

            // Deduplicate and sort by recency
            var seen = Set<String>()
            let deduplicated = allPosts.filter { post in
                guard let id = post.id, !seen.contains(id) else { return false }
                seen.insert(id)
                return true
            }

            self.posts = deduplicated.sorted {
                ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
            }
            self.hasMorePages = deduplicated.count >= pageSize
            self.isLoading = false
        }
    }

    private func loadMoreFollowing() async {
        guard let uid = auth.currentUser?.uid else { return }
        guard let lastDoc = lastDocument else {
            hasMorePages = false
            return
        }

        let socialIds = Array(friendIds.union(followingIds).union([uid]))
        let chunks = socialIds.chunked(into: 30)
        var newPosts: [Post] = []
        let existingIds = Set(posts.compactMap { $0.id })

        for chunk in chunks {
            do {
                let snapshot = try await db.collection("posts")
                    .whereField("authorId", in: chunk)
                    .order(by: "createdAt", descending: true)
                    .limit(to: pageSize)
                    .start(afterDocument: lastDoc)
                    .getDocuments()

                let chunkPosts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
                newPosts.append(contentsOf: chunkPosts)

                if let last = snapshot.documents.last {
                    self.lastDocument = last
                }
            } catch {
                // Fallback without ordering
                do {
                    let snapshot = try await db.collection("posts")
                        .whereField("authorId", in: chunk)
                        .limit(to: pageSize)
                        .getDocuments()
                    let chunkPosts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
                    newPosts.append(contentsOf: chunkPosts)
                } catch {
                    print("[Feed] Following loadMore error: \(error.localizedDescription)")
                }
            }
        }

        let deduplicated = newPosts.filter { post in
            guard let id = post.id else { return false }
            return !existingIds.contains(id)
        }.sorted {
            ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast)
        }

        posts.append(contentsOf: deduplicated)
        hasMorePages = !deduplicated.isEmpty
    }

    // MARK: - Unsorted Fallback

    private func loadPostsUnsorted() {
        listener?.remove()
        listener = db.collection("posts")
            .limit(to: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    print("[Feed] Fallback snapshot error: \(error.localizedDescription)")
                    return
                }

                let decoded = (snapshot?.documents ?? []).compactMap { try? $0.data(as: Post.self) }
                self.posts = decoded.sorted { ($0.createdAt?.dateValue() ?? .distantPast) > ($1.createdAt?.dateValue() ?? .distantPast) }
                self.lastDocument = snapshot?.documents.last
                self.hasMorePages = (snapshot?.documents.count ?? 0) >= self.pageSize
            }
    }

    func refresh() {
        listener?.remove()
        resetPagination()
        loadSocialGraph() // Refresh social graph on pull-to-refresh
        loadPosts()
    }

    // MARK: - Haversine Distance

    /// Calculate distance in km between two lat/lng coordinates using the Haversine formula.
    static func haversineDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0 // Earth radius in km
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    // MARK: - Reactions

    func toggleReaction(_ post: Post, type: ReactionType) {
        guard let uid = auth.currentUser?.uid, let postId = post.id else { return }
        let key = type.firestoreKey
        let docRef = db.collection("posts").document(postId)

        Task {
            let existingReaction = post.reactionBy?[uid]

            if existingReaction == key {
                // Remove reaction
                try? await docRef.updateData([
                    "reactionBy.\(uid)": FieldValue.delete(),
                    "reactions.\(key)": FieldValue.increment(Int64(-1))
                ])
            } else {
                var updates: [String: Any] = [
                    "reactionBy.\(uid)": key,
                    "reactions.\(key)": FieldValue.increment(Int64(1))
                ]
                // Decrement previous reaction if switching
                if let prev = existingReaction {
                    updates["reactions.\(prev)"] = FieldValue.increment(Int64(-1))
                }
                try? await docRef.updateData(updates)
            }
        }
    }

    // MARK: - Legacy like (maps to kudos reaction)

    func toggleLike(_ post: Post) {
        guard let uid = auth.currentUser?.uid else { return }
        Task {
            if post.likedBy.contains(uid) {
                try? await db.collection("posts").document(post.id ?? "").updateData([
                    "likedBy": FieldValue.arrayRemove([uid]),
                    "likeCount": FieldValue.increment(Int64(-1))
                ])
            } else {
                try? await db.collection("posts").document(post.id ?? "").updateData([
                    "likedBy": FieldValue.arrayUnion([uid]),
                    "likeCount": FieldValue.increment(Int64(1))
                ])
            }
        }
    }

    /// Check whether text contains URLs (anti-spam).
    func containsLink(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return Self.linkPattern.firstMatch(in: text, range: range) != nil
    }

    func createPost(text: String, photoUrl: String?) {
        guard let uid = auth.currentUser?.uid else { return }
        Task {
            let userDoc = try? await db.collection("users").document(uid).getDocument()
            let userName = userDoc?.data()?["username"] as? String ?? "User"
            let userAvatar = userDoc?.data()?["photoUrl"] as? String

            let post = Post(
                id: UUID().uuidString,
                authorId: uid,
                authorName: userName,
                authorAvatar: userAvatar,
                type: "TEXT",
                text: text,
                createdAt: Timestamp(),
                commentCount: 0,
                photoUrl: photoUrl,
                likeCount: 0,
                likedBy: []
            )
            try? db.collection("posts").document(post.id ?? "").setData(from: post)
        }
    }

    /// Upload a photo to Firebase Storage and create a post with the image URL.
    /// Storage path mirrors Android: feedPosts/{postId}/{imageId}.jpg
    func createPostWithImage(text: String, imageData: Data, locationTag: String? = nil) async throws {
        guard let uid = auth.currentUser?.uid else { return }

        // EXIF strip + resize. Raw image data often carries GPS tags from
        // camera capture — those must never leave the device.
        let sanitized = try ImageSanitizer.prepareForUpload(
            imageData: imageData,
            target: .feedPost
        )

        let postId = UUID().uuidString
        let imageId = UUID().uuidString
        let storageRef = storage.reference().child("feedPosts/\(postId)/\(imageId).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "uploadedBy": uid,
            "postId": postId
        ]
        _ = try await storageRef.putDataAsync(sanitized, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()

        let userDoc = try? await db.collection("users").document(uid).getDocument()
        let userName = userDoc?.data()?["username"] as? String ?? "User"
        let userAvatar = userDoc?.data()?["photoUrl"] as? String

        var postData: [String: Any] = [
            "authorId": uid,
            "authorName": userName,
            "type": "TEXT",
            "text": text,
            "photoUrl": downloadURL.absoluteString,
            "media": [["url": downloadURL.absoluteString, "type": "PHOTO"]],
            "createdAt": Timestamp(),
            "commentCount": 0,
            "likeCount": 0,
            "likedBy": [String](),
            "reactionBy": [String: String](),
            "bookmarkedBy": [String](),
            "shareCount": 0,
            "hashtags": extractHashtags(text)
        ]

        if let userAvatar { postData["authorAvatar"] = userAvatar }
        if let locationTag { postData["locationTag"] = locationTag }

        try await db.collection("posts").document(postId).setData(postData)
    }

    private func extractHashtags(_ text: String) -> [String] {
        let pattern = try? NSRegularExpression(pattern: "#\\w+")
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern?.matches(in: text, range: range) ?? []
        return matches.compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange]).lowercased()
        }
    }

    deinit { listener?.remove() }
}
