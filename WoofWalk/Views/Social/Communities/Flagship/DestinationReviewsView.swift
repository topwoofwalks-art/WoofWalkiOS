import SwiftUI
import FirebaseFirestore

// MARK: - View Model

@MainActor
class DestinationReviewsViewModel: ObservableObject {
    @Published var reviews: [DestinationReview] = []
    @Published var selectedCategory: String = "All"
    @Published var sortOption: String = "Recent"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAddSheet = false
    @Published var selectedReview: DestinationReview?

    private let db = Firestore.firestore()
    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    static let categories = ["All", "Park", "Cafe", "Beach", "Trail", "Pub", "Hotel", "Restaurant", "Shop", "Other"]
    static let sortOptions = ["Recent", "Top Rated", "Most Dog Friendly"]

    var filteredReviews: [DestinationReview] {
        var results = reviews
        if selectedCategory != "All" {
            results = results.filter { $0.destinationType.lowercased() == selectedCategory.lowercased() }
        }
        switch sortOption {
        case "Top Rated":
            results.sort { $0.rating > $1.rating }
        case "Most Dog Friendly":
            results.sort { $0.dogFriendlinessRating > $1.dogFriendlinessRating }
        default:
            results.sort { $0.createdAt > $1.createdAt }
        }
        return results
    }

    /// Average rating across grouped destinations
    var destinationCards: [(name: String, type: String, avgRating: Double, reviewCount: Int, reviews: [DestinationReview])] {
        let grouped = Dictionary(grouping: filteredReviews) { $0.destinationName }
        return grouped.map { name, reviews in
            let avg = reviews.reduce(0.0) { $0 + $1.rating } / Double(reviews.count)
            let type = reviews.first?.destinationType ?? ""
            return (name: name, type: type, avgRating: avg, reviewCount: reviews.count, reviews: reviews)
        }
        .sorted {
            switch sortOption {
            case "Top Rated": return $0.avgRating > $1.avgRating
            case "Most Dog Friendly":
                let aFriendly = $0.reviews.reduce(0.0) { $0 + $1.dogFriendlinessRating } / Double($0.reviews.count)
                let bFriendly = $1.reviews.reduce(0.0) { $0 + $1.dogFriendlinessRating } / Double($1.reviews.count)
                return aFriendly > bFriendly
            default:
                return ($0.reviews.first?.createdAt ?? 0) > ($1.reviews.first?.createdAt ?? 0)
            }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts")
                .whereField("type", isEqualTo: CommunityPostType.DESTINATION_REVIEW.rawValue)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            reviews = posts.compactMap { post -> DestinationReview? in
                guard let meta = post.metadata else { return nil }
                return DestinationReview(
                    id: post.id,
                    communityId: communityId,
                    postId: post.id ?? "",
                    destinationName: meta["destinationName"] ?? post.title,
                    destinationType: meta["destinationType"] ?? "",
                    locationName: post.locationName ?? "",
                    rating: Double(meta["rating"] ?? "0") ?? 0,
                    review: post.content,
                    photoUrls: post.mediaUrls,
                    dogFriendlinessRating: Double(meta["dogFriendlinessRating"] ?? "0") ?? 0,
                    hasWaterBowls: meta["hasWaterBowls"] == "true",
                    hasOffLeadArea: meta["hasOffLeadArea"] == "true",
                    hasDogMenu: meta["hasDogMenu"] == "true",
                    isAccessible: meta["isAccessible"] == "true",
                    createdBy: post.authorId,
                    createdAt: post.createdAt
                )
            }
            isLoading = false
        } catch {
            errorMessage = "Failed to load reviews"
            isLoading = false
        }
    }

    func categoryIcon(_ category: String) -> String {
        switch category.lowercased() {
        case "park": return "leaf.fill"
        case "cafe", "restaurant": return "cup.and.saucer.fill"
        case "beach": return "water.waves"
        case "trail": return "figure.hiking"
        case "pub": return "mug.fill"
        case "hotel": return "bed.double.fill"
        case "shop": return "bag.fill"
        default: return "mappin.circle.fill"
        }
    }
}

// MARK: - View

struct DestinationReviewsView: View {
    let communityId: String
    @StateObject private var viewModel: DestinationReviewsViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: DestinationReviewsViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DestinationReviewsViewModel.categories, id: \.self) { cat in
                        Button {
                            viewModel.selectedCategory = cat
                        } label: {
                            HStack(spacing: 4) {
                                if cat != "All" {
                                    Image(systemName: viewModel.categoryIcon(cat))
                                        .font(.caption2)
                                }
                                Text(cat)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(viewModel.selectedCategory == cat ? Color.turquoise60 : Color(.systemGray6)))
                            .foregroundColor(viewModel.selectedCategory == cat ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Sort
            HStack {
                Text("\(viewModel.destinationCards.count) destination\(viewModel.destinationCards.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Menu {
                    ForEach(DestinationReviewsViewModel.sortOptions, id: \.self) { option in
                        Button {
                            viewModel.sortOption = option
                        } label: {
                            HStack {
                                Text(option)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2)
                        Text(viewModel.sortOption)
                            .font(.caption)
                    }
                    .foregroundColor(.turquoise60)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.destinationCards.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.destinationCards, id: \.name) { destination in
                            DestinationCard(
                                destination: destination,
                                categoryIcon: viewModel.categoryIcon(destination.type)
                            )
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.load() }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Review")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.turquoise60))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            CreateCommunityPostSheet(communityId: communityId) {
                Task { await viewModel.load() }
            }
        }
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No Reviews Yet")
                .font(.headline)
            Text("Be the first to review a dog-friendly destination for the community")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.showAddSheet = true
            } label: {
                Label("Write a Review", systemImage: "plus.circle")
                    .font(.subheadline.bold())
                    .foregroundColor(.turquoise60)
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Destination Card

private struct DestinationCard: View {
    let destination: (name: String, type: String, avgRating: Double, reviewCount: Int, reviews: [DestinationReview])
    let categoryIcon: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover photo
            if let firstReview = destination.reviews.first(where: { !$0.photoUrls.isEmpty }),
               let firstUrl = firstReview.photoUrls.first,
               let url = URL(string: firstUrl) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.neutral90)
                }
                .frame(height: 140)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: categoryIcon)
                        .foregroundColor(.turquoise60)
                    Text(destination.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if !destination.type.isEmpty {
                        Text(destination.type)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(.systemGray6)))
                            .foregroundColor(.secondary)
                    }
                }

                // Rating
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= destination.avgRating ? "star.fill" :
                                    (Double(star) - 0.5 <= destination.avgRating ? "star.leadinghalf.filled" : "star"))
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    Text(String(format: "%.1f", destination.avgRating))
                        .font(.subheadline.bold())
                    Text("(\(destination.reviewCount) review\(destination.reviewCount == 1 ? "" : "s"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Amenities from latest review
                if let latest = destination.reviews.first {
                    HStack(spacing: 8) {
                        if latest.hasWaterBowls {
                            amenityBadge("Water Bowls", icon: "drop.fill")
                        }
                        if latest.hasOffLeadArea {
                            amenityBadge("Off-Lead", icon: "figure.walk")
                        }
                        if latest.hasDogMenu {
                            amenityBadge("Dog Menu", icon: "fork.knife")
                        }
                        if latest.isAccessible {
                            amenityBadge("Accessible", icon: "figure.roll")
                        }
                    }
                }

                // Expandable reviews
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Hide reviews" : "Show reviews")
                            .font(.caption)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.turquoise60)
                }

                if isExpanded {
                    ForEach(destination.reviews) { review in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: Double(star) <= review.rating ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                Spacer()
                                Text(formatDate(review.createdAt))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(review.review)
                                .font(.caption)
                                .lineLimit(4)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                    }
                }
            }
            .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func amenityBadge(_ label: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.turquoise90))
        .foregroundColor(.turquoise30)
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
