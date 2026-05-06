import SwiftUI

/// Top-level browse screen for communities. Mirrors Android's
/// `CommunityListScreen`:
///   - search bar
///   - filter chips (All / Breed / Local / Training / Rescue / Puppy /
///     Senior / Sports / Travel / Health)
///   - sections: My / Featured / Trending / Discover (each filtered)
///   - pull-to-refresh
///   - FAB → CreateCommunityScreen
///
/// Filters apply to ALL four sections (Android audit fix in commit
/// `ec9cbc2`) so a search can't skip a community in My/Trending.
struct CommunityListScreen: View {
    @StateObject private var viewModel = CommunityListViewModel()
    @State private var showCreate = false
    @State private var selectedCommunityId: String?

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    private struct FilterChip: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let type: CommunityType?
    }

    private static let filterChips: [FilterChip] = [
        .init(label: "All", type: nil),
        .init(label: "Breed", type: .breedSpecific),
        .init(label: "Local", type: .localNeighbourhood),
        .init(label: "Training", type: .trainingBehaviour),
        .init(label: "Rescue", type: .rescueRehoming),
        .init(label: "Puppy", type: .puppyParents),
        .init(label: "Senior", type: .seniorDogs),
        .init(label: "Sports", type: .dogSports),
        .init(label: "Travel", type: .dogFriendlyTravel),
        .init(label: "Health", type: .healthNutrition)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: []) {
                        searchBar
                        filterChipsRow

                        let my = viewModel.applyFilter(viewModel.myCommunities)
                        let featured = viewModel.applyFilter(viewModel.featured)
                        let trending = viewModel.applyFilter(viewModel.trending)
                        let discover = viewModel.applyFilter(viewModel.discover)

                        if !my.isEmpty {
                            sectionHeader("My Communities")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(my) { community in
                                        Button {
                                            if let id = community.id { selectedCommunityId = id }
                                        } label: {
                                            CompactCommunityCard(community: community)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        if !featured.isEmpty {
                            sectionHeader("Featured")
                            ForEach(featured.prefix(5)) { community in
                                CommunityListCard(community: community) {
                                    if let id = community.id { selectedCommunityId = id }
                                }
                            }
                        }

                        if !trending.isEmpty {
                            sectionHeader("Trending")
                            ForEach(trending) { community in
                                CommunityListCard(community: community) {
                                    if let id = community.id { selectedCommunityId = id }
                                }
                            }
                        }

                        sectionHeader("Discover")
                        if discover.isEmpty && !viewModel.isLoading {
                            emptyDiscoverState
                        } else {
                            ForEach(discover) { community in
                                CommunityListCard(community: community) {
                                    if let id = community.id { selectedCommunityId = id }
                                }
                            }
                        }

                        if viewModel.isLoading {
                            ProgressView().padding()
                        }

                        Spacer().frame(height: 80)
                    }
                    .padding(.top, 8)
                }
                .refreshable { viewModel.refresh() }

                createFAB
            }
            .navigationTitle("Communities")
            .navigationBarTitleDisplayMode(.inline)
            // Use the String-based navigationDestination (available iOS 16+)
            // — `navigationDestination(item:)` requires iOS 17, but the
            // project targets iOS 16. Bind to a non-optional via the
            // isPresented overload.
            .navigationDestination(isPresented: Binding(
                get: { selectedCommunityId != nil },
                set: { if !$0 { selectedCommunityId = nil } }
            )) {
                if let id = selectedCommunityId {
                    CommunityDetailScreen(communityId: id)
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateCommunityScreen { newId in
                    showCreate = false
                    if let newId { selectedCommunityId = newId }
                }
            }
        }
    }

    // MARK: - Sub views

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search communities...", text: $viewModel.searchQuery)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.filterChips) { chip in
                    let isSelected = viewModel.selectedTypeFilter == chip.type
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.selectedTypeFilter = chip.type
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text(chip.label)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isSelected ? Self.brandColor.opacity(0.15) : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isSelected ? Self.brandColor : Color.clear, lineWidth: 1)
                        )
                        .foregroundColor(isSelected ? Self.brandColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var emptyDiscoverState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No communities found")
                .font(.headline)
            Text("Try a different search or create your own community.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var createFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Self.brandColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Cards

/// Compact 140×160 card for the My Communities horizontal row.
private struct CompactCommunityCard: View {
    let community: Community

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cover
                .frame(width: 140, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(community.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(community.memberCount) members")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(maxWidth: 140, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            CommunityTypeBadge(type: community.type)
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: 140, height: 160)
    }

    @ViewBuilder
    private var cover: some View {
        if let urlStr = community.coverPhotoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    typeColorPlaceholder
                }
            }
        } else {
            typeColorPlaceholder
        }
    }

    private var typeColorPlaceholder: some View {
        let c = community.type.color
        return Color(red: c.red, green: c.green, blue: c.blue).opacity(0.3)
    }
}

/// Full-width card for Featured / Trending / Discover sections. 120pt cover
/// (vs Android's `120.dp`) to keep the proportions identical across
/// platforms.
private struct CommunityListCard: View {
    let community: Community
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    cover.frame(maxWidth: .infinity).frame(height: 120)
                    HStack(spacing: 6) {
                        if community.privacy != .public {
                            Image(systemName: community.privacy.iconSystemName)
                                .font(.system(size: 12))
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        CommunityTypeBadge(type: community.type)
                    }
                    .padding(8)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(community.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(community.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("\(community.memberCount) members")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cover: some View {
        if let urlStr = community.coverPhotoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill).clipped()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        let c = community.type.color
        return ZStack {
            Color(red: c.red, green: c.green, blue: c.blue).opacity(0.25)
            Image(systemName: community.type.iconSystemName)
                .font(.system(size: 32))
                .foregroundColor(Color(red: c.red, green: c.green, blue: c.blue))
        }
    }
}

/// Coloured pill identifying a community's type. Reusable across cards and
/// the detail header.
struct CommunityTypeBadge: View {
    let type: CommunityType

    var body: some View {
        let c = type.color
        Text(type.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(red: c.red, green: c.green, blue: c.blue).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
