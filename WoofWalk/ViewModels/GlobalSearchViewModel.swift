import Foundation
import Combine
import FirebaseFirestore

/// Multi-collection search across users, posts, communities and businesses.
/// iOS port of Android's `GlobalSearchViewModel.kt`. The query string is
/// debounced (300 ms) and fanned out to all four Firestore collections in
/// parallel; each result type is capped at `perTypeLimit` (25). Results
/// are grouped by type in `SearchResults` and surfaced to the view as a
/// single `@Published` struct.
///
/// Query strategy — Firestore has no `contains` operator, so we use the
/// standard prefix-match trick (`whereField(... isGreaterThanOrEqualTo: q)`
/// + `... isLessThan: q + "\u{f8ff}"`) over pre-lowercased index fields
/// (`displayNameLower`, `nameLower`, `businessNameLower`). Posts use
/// `textTokens` (array-contains on tokenised words) because there's no
/// short prefix-equivalent for free-form text — same approach as Android.
@MainActor
final class GlobalSearchViewModel: ObservableObject {

    @Published var query: String = ""
    @Published var results: SearchResults = SearchResults()
    @Published var isSearching: Bool = false
    @Published var hasSearched: Bool = false

    private let db = Firestore.firestore()
    private let perTypeLimit: Int = 25
    private let debounceMs: Int = 300
    private var debounceTask: Task<Void, Never>? = nil
    private var inflightTask: Task<Void, Never>? = nil

    init() {}

    /// Update the query string. Debounces 300 ms before kicking off the
    /// actual Firestore fan-out, so a fast typer doesn't hammer the
    /// backend or surface partial results from older inflight requests.
    func setQuery(_ q: String) {
        query = q
        debounceTask?.cancel()
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            inflightTask?.cancel()
            results = SearchResults()
            isSearching = false
            hasSearched = false
            return
        }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.debounceMs ?? 300) * 1_000_000)
            if Task.isCancelled { return }
            await self?.runSearch(trimmed.lowercased())
        }
    }

    func clear() {
        debounceTask?.cancel()
        inflightTask?.cancel()
        query = ""
        results = SearchResults()
        isSearching = false
        hasSearched = false
    }

    // MARK: - Fan-out

    private func runSearch(_ q: String) async {
        inflightTask?.cancel()
        isSearching = true
        hasSearched = true

        let limit = perTypeLimit
        let task = Task { [weak self] in
            guard let self = self else { return }
            // Run all four in parallel; tolerate per-type failures so a
            // missing index in one collection doesn't kill the whole UI.
            async let users = self.searchUsers(prefix: q, limit: limit)
            async let posts = self.searchPosts(prefix: q, limit: limit)
            async let communities = self.searchCommunities(prefix: q, limit: limit)
            async let businesses = self.searchBusinesses(prefix: q, limit: limit)

            let merged = SearchResults(
                users: await users,
                posts: await posts,
                communities: await communities,
                businesses: await businesses
            )
            if Task.isCancelled { return }
            await MainActor.run {
                self.results = merged
                self.isSearching = false
            }
        }
        inflightTask = task
    }

    // MARK: - Per-collection queries

    private func searchUsers(prefix: String, limit: Int) async -> [UserSearchResult] {
        let end = prefix + "\u{f8ff}"
        // Prefer the dedicated lower-case search field if present
        // (`searchableDisplayName`), fall back to `displayNameLower` (other
        // backends use this name) and finally `username` for older docs.
        for field in ["searchableDisplayName", "displayNameLower", "username"] {
            do {
                let snap = try await db.collection("users")
                    .whereField(field, isGreaterThanOrEqualTo: prefix)
                    .whereField(field, isLessThan: end)
                    .limit(to: limit)
                    .getDocuments()
                if !snap.documents.isEmpty {
                    return snap.documents.compactMap { doc in
                        let d = doc.data()
                        let name = (d["displayName"] as? String)
                            ?? (d["username"] as? String)
                            ?? "Walker"
                        return UserSearchResult(
                            uid: doc.documentID,
                            displayName: name,
                            photoUrl: d["photoUrl"] as? String,
                            bio: (d["bio"] as? String) ?? ""
                        )
                    }
                }
            } catch {
                // Index missing on this field — try the next variant.
                continue
            }
        }
        return []
    }

    private func searchPosts(prefix: String, limit: Int) async -> [PostSearchResult] {
        // Firestore can't do substring search on `text`. Android indexes a
        // `textTokens` array (lower-cased word list) and matches with
        // array-contains; we do the same. Falls back silently if the field
        // / index isn't present yet.
        do {
            let snap = try await db.collection("posts")
                .whereField("textTokens", arrayContains: prefix)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc in
                let d = doc.data()
                let text = (d["text"] as? String)
                    ?? (d["content"] as? String)
                    ?? (d["caption"] as? String)
                    ?? ""
                return PostSearchResult(
                    postId: doc.documentID,
                    authorId: (d["authorId"] as? String) ?? "",
                    authorName: (d["authorName"] as? String) ?? "Walker",
                    authorAvatar: d["authorAvatar"] as? String,
                    text: text,
                    photoUrl: (d["photoUrl"] as? String)
                        ?? ((d["media"] as? [[String: Any]])?.first?["url"] as? String),
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    commentCount: (d["commentCount"] as? Int) ?? 0
                )
            }
        } catch {
            return []
        }
    }

    private func searchCommunities(prefix: String, limit: Int) async -> [CommunitySearchResult] {
        let end = prefix + "\u{f8ff}"
        for field in ["nameLower", "searchableName"] {
            do {
                let snap = try await db.collection("communities")
                    .whereField(field, isGreaterThanOrEqualTo: prefix)
                    .whereField(field, isLessThan: end)
                    .limit(to: limit)
                    .getDocuments()
                if !snap.documents.isEmpty {
                    return snap.documents.compactMap { doc in
                        let d = doc.data()
                        return CommunitySearchResult(
                            communityId: doc.documentID,
                            name: (d["name"] as? String) ?? "",
                            description: (d["description"] as? String) ?? "",
                            coverPhotoUrl: d["coverPhotoUrl"] as? String,
                            memberCount: (d["memberCount"] as? Int) ?? 0,
                            isFeatured: (d["isFeatured"] as? Bool) ?? false
                        )
                    }
                }
            } catch {
                continue
            }
        }
        return []
    }

    private func searchBusinesses(prefix: String, limit: Int) async -> [BusinessSearchResult] {
        let end = prefix + "\u{f8ff}"
        // Businesses use any of: `displayNameLower`, `nameLower`,
        // `businessNameLower`. Try each until one returns rows or all
        // fail. The first variant matched the Android signature on the
        // task description (`whereGreaterThanOrEqualTo("displayNameLower")`).
        for field in ["displayNameLower", "nameLower", "businessNameLower"] {
            do {
                let snap = try await db.collection("businesses")
                    .whereField(field, isGreaterThanOrEqualTo: prefix)
                    .whereField(field, isLessThan: end)
                    .limit(to: limit)
                    .getDocuments()
                if !snap.documents.isEmpty {
                    return snap.documents.compactMap { doc in
                        let d = doc.data()
                        let name = (d["displayName"] as? String)
                            ?? (d["name"] as? String)
                            ?? (d["businessName"] as? String)
                            ?? "Business"
                        let services = (d["services"] as? [String])
                            ?? (d["serviceTypes"] as? [String])
                            ?? []
                        return BusinessSearchResult(
                            businessId: doc.documentID,
                            name: name,
                            photoUrl: (d["heroPhotoUrl"] as? String) ?? (d["photoUrl"] as? String),
                            services: services,
                            rating: d["rating"] as? Double,
                            city: (d["address"] as? [String: Any])?["city"] as? String
                                ?? d["city"] as? String
                        )
                    }
                }
            } catch {
                continue
            }
        }
        return []
    }
}

// MARK: - Result models

struct SearchResults {
    var users: [UserSearchResult] = []
    var posts: [PostSearchResult] = []
    var communities: [CommunitySearchResult] = []
    var businesses: [BusinessSearchResult] = []

    var totalCount: Int {
        users.count + posts.count + communities.count + businesses.count
    }

    var isEmpty: Bool { totalCount == 0 }
}

enum SearchCategory: String, CaseIterable, Identifiable {
    case all
    case people
    case posts
    case communities
    case businesses

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .people: return "People"
        case .posts: return "Posts"
        case .communities: return "Communities"
        case .businesses: return "Businesses"
        }
    }

    var iconSystemName: String {
        switch self {
        case .all: return "magnifyingglass"
        case .people: return "person.2.fill"
        case .posts: return "doc.text"
        case .communities: return "person.3.fill"
        case .businesses: return "storefront.fill"
        }
    }
}

struct UserSearchResult: Identifiable, Hashable {
    let uid: String
    let displayName: String
    let photoUrl: String?
    let bio: String

    var id: String { uid }
}

struct PostSearchResult: Identifiable, Hashable {
    let postId: String
    let authorId: String
    let authorName: String
    let authorAvatar: String?
    let text: String
    let photoUrl: String?
    let likeCount: Int
    let commentCount: Int

    var id: String { postId }
}

struct CommunitySearchResult: Identifiable, Hashable {
    let communityId: String
    let name: String
    let description: String
    let coverPhotoUrl: String?
    let memberCount: Int
    let isFeatured: Bool

    var id: String { communityId }
}

struct BusinessSearchResult: Identifiable, Hashable {
    let businessId: String
    let name: String
    let photoUrl: String?
    let services: [String]
    let rating: Double?
    let city: String?

    var id: String { businessId }
}
