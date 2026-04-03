import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class CommunityListViewModel: ObservableObject {
    @Published var communities: [Community] = []
    @Published var myCommunities: [Community] = []
    @Published var trendingCommunities: [Community] = []
    @Published var searchQuery: String = ""
    @Published var selectedType: CommunityType?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let auth = Auth.auth()

    init() {
        loadCommunities()
    }

    // MARK: - Load All Communities

    func loadCommunities() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let snapshot = try await db.collection("communities")
                    .whereField("isArchived", isEqualTo: false)
                    .order(by: "memberCount", descending: true)
                    .limit(to: 50)
                    .getDocuments()

                self.communities = snapshot.documents.compactMap { try? $0.data(as: Community.self) }
                self.isLoading = false
            } catch {
                print("[Communities] Error loading communities: \(error.localizedDescription)")
                // Fallback without ordering
                do {
                    let snapshot = try await db.collection("communities")
                        .whereField("isArchived", isEqualTo: false)
                        .limit(to: 50)
                        .getDocuments()

                    self.communities = snapshot.documents.compactMap { try? $0.data(as: Community.self) }
                        .sorted { $0.memberCount > $1.memberCount }
                } catch {
                    self.errorMessage = error.localizedDescription
                    print("[Communities] Fallback error: \(error.localizedDescription)")
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - Search

    func searchCommunities() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            loadCommunities()
            return
        }

        isLoading = true
        errorMessage = nil
        let query = searchQuery.lowercased()

        Task {
            do {
                let snapshot = try await db.collection("communities")
                    .whereField("isArchived", isEqualTo: false)
                    .limit(to: 100)
                    .getDocuments()

                let allCommunities = snapshot.documents.compactMap { try? $0.data(as: Community.self) }
                self.communities = allCommunities.filter { community in
                    community.name.lowercased().contains(query) ||
                    community.description.lowercased().contains(query) ||
                    community.tags.contains(where: { $0.lowercased().contains(query) })
                }
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("[Communities] Search error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Filter by Type

    func filterByType(_ type: CommunityType?) {
        selectedType = type

        guard let type = type else {
            loadCommunities()
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let snapshot = try await db.collection("communities")
                    .whereField("type", isEqualTo: type.rawValue)
                    .whereField("isArchived", isEqualTo: false)
                    .limit(to: 50)
                    .getDocuments()

                self.communities = snapshot.documents.compactMap { try? $0.data(as: Community.self) }
                    .sorted { $0.memberCount > $1.memberCount }
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("[Communities] Filter error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - My Communities

    func loadMyCommunities() {
        guard let uid = auth.currentUser?.uid else { return }

        Task {
            do {
                // Query community memberships for current user
                let membershipSnapshots = try await db.collectionGroup("members")
                    .whereField("userId", isEqualTo: uid)
                    .whereField("isBanned", isEqualTo: false)
                    .getDocuments()

                let communityIds = membershipSnapshots.documents.compactMap { doc -> String? in
                    return doc.data()["communityId"] as? String
                }

                guard !communityIds.isEmpty else {
                    self.myCommunities = []
                    return
                }

                // Fetch communities in chunks of 30 (Firestore limit)
                var results: [Community] = []
                for chunk in communityIds.chunked(into: 30) {
                    let snapshot = try await db.collection("communities")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    let communities = snapshot.documents.compactMap { try? $0.data(as: Community.self) }
                    results.append(contentsOf: communities)
                }

                self.myCommunities = results.sorted { $0.memberCount > $1.memberCount }
            } catch {
                print("[Communities] Error loading my communities: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Trending

    func loadTrending() {
        Task {
            do {
                let snapshot = try await db.collection("communities")
                    .whereField("isArchived", isEqualTo: false)
                    .whereField("isFeatured", isEqualTo: true)
                    .limit(to: 20)
                    .getDocuments()

                var trending = snapshot.documents.compactMap { try? $0.data(as: Community.self) }

                // If not enough featured, fill with highest member count communities
                if trending.count < 10 {
                    let moreSnapshot = try await db.collection("communities")
                        .whereField("isArchived", isEqualTo: false)
                        .limit(to: 20)
                        .getDocuments()

                    let existing = Set(trending.compactMap { $0.id })
                    let more = moreSnapshot.documents.compactMap { try? $0.data(as: Community.self) }
                        .filter { $0.id != nil && !existing.contains($0.id!) }
                        .sorted { $0.memberCount > $1.memberCount }

                    trending.append(contentsOf: more.prefix(10 - trending.count))
                }

                self.trendingCommunities = trending.sorted { $0.memberCount > $1.memberCount }
            } catch {
                print("[Communities] Error loading trending: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Refresh

    func refresh() {
        loadCommunities()
        loadMyCommunities()
        loadTrending()
    }
}

// MARK: - Array Chunking Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
