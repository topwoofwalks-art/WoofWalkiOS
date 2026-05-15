import SwiftUI

/// App-wide search screen — iOS port of Android `GlobalSearchScreen.kt`.
///
/// Single debounced text input fans out across four Firestore collections
/// (users, posts, communities, businesses). Category chips at the top let
/// the user narrow to a single result type. Each row taps through to the
/// existing detail screen for that type via `AppRoute`.
///
/// Reached from the Social tab's toolbar magnifying-glass — see
/// `SocialHubScreen.swift` (also wired into `SocialHubScreenV2.swift` for
/// the upcoming redesign).
struct GlobalSearchScreen: View {
    @StateObject private var viewModel = GlobalSearchViewModel()
    @State private var selectedCategory: SearchCategory = .all
    @FocusState private var queryFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            categoryChips
            Divider()
            content
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { queryFocused = true }
    }

    // MARK: - Header

    private var searchField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search WoofWalk", text: Binding(
                    get: { viewModel.query },
                    set: { viewModel.setQuery($0) }
                ))
                .focused($queryFocused)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)

                if !viewModel.query.isEmpty {
                    Button(action: { viewModel.clear() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }

                if viewModel.isSearching {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchCategory.allCases) { cat in
                    let selected = cat == selectedCategory
                    Button {
                        selectedCategory = cat
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.iconSystemName)
                                .font(.caption2)
                            Text(cat.title)
                                .font(.subheadline)
                                .fontWeight(selected ? .semibold : .regular)
                            if cat != .all && count(for: cat) > 0 {
                                Text("\(count(for: cat))")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule().fill(
                                            selected
                                                ? Color.white.opacity(0.25)
                                                : Color(.systemGray5)
                                        )
                                    )
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                selected
                                    ? Color(red: 0/255, green: 160/255, blue: 176/255)
                                    : Color(.systemGray6)
                            )
                        )
                        .foregroundColor(selected ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func count(for category: SearchCategory) -> Int {
        switch category {
        case .all: return viewModel.results.totalCount
        case .people: return viewModel.results.users.count
        case .posts: return viewModel.results.posts.count
        case .communities: return viewModel.results.communities.count
        case .businesses: return viewModel.results.businesses.count
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        let q = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            emptyHero
        } else if viewModel.results.isEmpty && viewModel.hasSearched && !viewModel.isSearching {
            noResultsView
        } else {
            resultsList
        }
    }

    private var emptyHero: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.5))
            Text("Search WoofWalk")
                .font(.title3.bold())
            Text("Find walkers, posts, breed communities and local dog-friendly businesses. Start typing above.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No matches")
                .font(.title3.bold())
            Text("Try a different name, breed, or city.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                let r = viewModel.results

                if selectedCategory == .all || selectedCategory == .people {
                    if !r.users.isEmpty {
                        sectionHeader("People", count: r.users.count)
                        ForEach(r.users) { user in
                            NavigationLink(value: AppRoute.publicProfile(userId: user.uid)) {
                                UserSearchRow(user: user)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 76)
                        }
                    }
                }

                if selectedCategory == .all || selectedCategory == .posts {
                    if !r.posts.isEmpty {
                        sectionHeader("Posts", count: r.posts.count)
                        ForEach(r.posts) { post in
                            NavigationLink(value: AppRoute.postDetail(postId: post.postId)) {
                                PostSearchRow(post: post)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 76)
                        }
                    }
                }

                if selectedCategory == .all || selectedCategory == .communities {
                    if !r.communities.isEmpty {
                        sectionHeader("Communities", count: r.communities.count)
                        ForEach(r.communities) { community in
                            NavigationLink(value: AppRoute.communityDetail(communityId: community.communityId)) {
                                CommunitySearchRow(community: community)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 76)
                        }
                    }
                }

                if selectedCategory == .all || selectedCategory == .businesses {
                    if !r.businesses.isEmpty {
                        sectionHeader("Businesses", count: r.businesses.count)
                        ForEach(r.businesses) { business in
                            NavigationLink(value: AppRoute.providerDetail(providerId: business.businessId)) {
                                BusinessSearchRow(business: business)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 76)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .navigationDestination(for: AppRoute.self) { route in
            RouteDestination(route: route)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            Text("·  \(count)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}

// MARK: - Rows

private struct UserSearchRow: View {
    let user: UserSearchResult

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                size: 44
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct PostSearchRow: View {
    let post: PostSearchResult

    var body: some View {
        HStack(spacing: 12) {
            if let photoUrl = post.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                        .frame(width: 48, height: 48)
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorName)
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                Text(post.text.isEmpty ? "[no caption]" : post.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct CommunitySearchRow: View {
    let community: CommunitySearchResult

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.15))
                    .frame(width: 44, height: 44)
                if let photoUrl = community.coverPhotoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        default: Color.clear
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(community.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    if community.isFeatured {
                        Text("Featured")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.orange.opacity(0.18))
                            )
                            .foregroundColor(.orange)
                    }
                }
                Text("\(community.memberCount) \(community.memberCount == 1 ? "member" : "members")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct BusinessSearchRow: View {
    let business: BusinessSearchResult

    var body: some View {
        HStack(spacing: 12) {
            if let photoUrl = business.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default: Color(.systemGray5)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "storefront.fill")
                        .foregroundColor(.orange)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(business.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                HStack(spacing: 6) {
                    if let rating = business.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let city = business.city, !city.isEmpty {
                        Text(city)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let first = business.services.first {
                        Text(first.capitalized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct GlobalSearchScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GlobalSearchScreen()
        }
    }
}
