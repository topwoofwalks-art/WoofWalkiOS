import Foundation
import FirebaseAuth
import Combine

/// Drives `CommunityListScreen`. Owns four parallel listeners (My / Featured
/// / Trending / Discover) so all four sections light up at once. Search +
/// type filter are applied in the view (matches Android's audit-fix where
/// filters apply to ALL four sections, not just Discover).
@MainActor
final class CommunityListViewModel: ObservableObject {
    @Published var myCommunities: [Community] = []
    @Published var featured: [Community] = []
    @Published var trending: [Community] = []
    @Published var discover: [Community] = []
    @Published var searchQuery: String = ""
    @Published var selectedTypeFilter: CommunityType?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let repository: CommunityRepository
    private let auth = Auth.auth()
    private var cancellables = Set<AnyCancellable>()

    init(repository: CommunityRepository = .shared) {
        self.repository = repository
        bind()
    }

    // MARK: - Listeners

    private func bind() {
        loadDiscover()
        loadFeatured()
        loadTrending()
        loadMyCommunities()
    }

    func loadDiscover() {
        isLoading = true
        repository.listenDiscoverCommunities()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] communities in
                self?.discover = communities
                self?.isLoading = false
            }
            .store(in: &cancellables)
    }

    func loadFeatured() {
        repository.listenFeaturedCommunities()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] communities in
                self?.featured = communities
            }
            .store(in: &cancellables)
    }

    func loadTrending() {
        repository.listenTrendingCommunities()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] communities in
                self?.trending = communities
            }
            .store(in: &cancellables)
    }

    func loadMyCommunities() {
        guard let userId = auth.currentUser?.uid else { return }
        repository.listenMyCommunities(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] communities in
                self?.myCommunities = communities
            }
            .store(in: &cancellables)
    }

    // MARK: - Filtering

    /// Apply search + type filter to a section. Searches name, description,
    /// and tags case-insensitively (parity with Android's
    /// CommunityListScreen.applyFilter).
    func applyFilter(_ list: [Community]) -> [Community] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        return list.filter { c in
            let typeMatch = selectedTypeFilter == nil || c.type == selectedTypeFilter
            let queryMatch = q.isEmpty
                || c.name.lowercased().contains(q)
                || c.description.lowercased().contains(q)
                || c.tags.contains(where: { $0.lowercased().contains(q) })
            return typeMatch && queryMatch
        }
    }

    func refresh() {
        cancellables.removeAll()
        bind()
    }

    func clearError() { error = nil }
}
