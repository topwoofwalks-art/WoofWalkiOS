import SwiftUI
import FirebaseFirestore

// MARK: - View Model

@MainActor
class AdoptionBoardViewModel: ObservableObject {
    @Published var listings: [AdoptionListing] = []
    @Published var filteredListings: [AdoptionListing] = []
    @Published var selectedStatus: String = "All"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCreateSheet = false
    @Published var selectedListing: AdoptionListing?

    private let db = Firestore.firestore()
    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    static let statusFilters = ["All", "AVAILABLE", "PENDING", "ADOPTED"]

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts")
                .whereField("type", isEqualTo: CommunityPostType.ADOPTION_LISTING.rawValue)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            listings = posts.compactMap { post -> AdoptionListing? in
                guard let meta = post.metadata else { return nil }
                return AdoptionListing(
                    communityId: communityId,
                    postId: post.id ?? "",
                    dogName: meta["dogName"] ?? "",
                    breed: meta["breed"] ?? "",
                    age: Int(meta["age"] ?? "0") ?? 0,
                    sex: meta["sex"] ?? "",
                    photoUrls: post.mediaUrls,
                    description: post.content,
                    status: meta["status"] ?? "AVAILABLE",
                    createdBy: post.authorId,
                    createdAt: post.createdAt
                )
            }
            applyFilter()
            isLoading = false
        } catch {
            errorMessage = "Failed to load adoption listings"
            isLoading = false
        }
    }

    func applyFilter() {
        if selectedStatus == "All" {
            filteredListings = listings
        } else {
            filteredListings = listings.filter { $0.status == selectedStatus }
        }
    }

    func statusDisplayName(_ status: String) -> String {
        switch status {
        case "AVAILABLE": return "Available"
        case "PENDING": return "Pending"
        case "ADOPTED": return "Adopted"
        default: return status
        }
    }

    func statusColor(_ status: String) -> Color {
        switch status {
        case "AVAILABLE": return .green
        case "PENDING": return .orange
        case "ADOPTED": return .blue
        default: return .secondary
        }
    }
}

// MARK: - View

struct AdoptionBoardView: View {
    let communityId: String
    @StateObject private var viewModel: AdoptionBoardViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: AdoptionBoardViewModel(communityId: communityId))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AdoptionBoardViewModel.statusFilters, id: \.self) { status in
                        Button {
                            viewModel.selectedStatus = status
                            viewModel.applyFilter()
                        } label: {
                            Text(status == "All" ? "All" : viewModel.statusDisplayName(status))
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(viewModel.selectedStatus == status ? Color.turquoise60 : Color(.systemGray6))
                                )
                                .foregroundColor(viewModel.selectedStatus == status ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.filteredListings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.filteredListings) { listing in
                            AdoptionCard(listing: listing, viewModel: viewModel)
                                .onTapGesture { viewModel.selectedListing = listing }
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.load() }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                viewModel.showCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.turquoise60))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateCommunityPostSheet(communityId: communityId) {
                Task { await viewModel.load() }
            }
        }
        .sheet(item: $viewModel.selectedListing) { listing in
            AdoptionDetailSheet(listing: listing, viewModel: viewModel)
        }
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart.circle")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No Adoption Listings")
                .font(.headline)
            Text("Dogs looking for forever homes will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.showCreateSheet = true
            } label: {
                Label("List a Dog", systemImage: "plus.circle")
                    .font(.subheadline.bold())
                    .foregroundColor(.turquoise60)
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Adoption Card

private struct AdoptionCard: View {
    let listing: AdoptionListing
    let viewModel: AdoptionBoardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo
            if let firstUrl = listing.photoUrls.first, let url = URL(string: firstUrl) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.neutral90)
                        .overlay(Image(systemName: "pawprint.fill").foregroundColor(.secondary))
                }
                .frame(height: 140)
                .clipped()
            } else {
                Rectangle().fill(Color(.systemGray6))
                    .frame(height: 140)
                    .overlay {
                        Image(systemName: "pawprint.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(listing.dogName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer()
                    // Status badge
                    Text(viewModel.statusDisplayName(listing.status))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(viewModel.statusColor(listing.status).opacity(0.15)))
                        .foregroundColor(viewModel.statusColor(listing.status))
                }

                Text(listing.breed)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if listing.age > 0 {
                        Label("\(listing.age)y", systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if !listing.sex.isEmpty {
                        Label(listing.sex, systemImage: listing.sex == "Male" ? "circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Adoption Detail Sheet

private struct AdoptionDetailSheet: View {
    let listing: AdoptionListing
    let viewModel: AdoptionBoardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Photo gallery
                    if !listing.photoUrls.isEmpty {
                        TabView {
                            ForEach(listing.photoUrls, id: \.self) { urlString in
                                if let url = URL(string: urlString) {
                                    AsyncImage(url: url) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(Color.neutral90)
                                    }
                                }
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Name + Status
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.dogName)
                                .font(.title2.bold())
                            Text(listing.breed)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(viewModel.statusDisplayName(listing.status))
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(viewModel.statusColor(listing.status).opacity(0.15)))
                            .foregroundColor(viewModel.statusColor(listing.status))
                    }

                    // Details grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        detailItem(icon: "calendar", label: "Age", value: "\(listing.age) year\(listing.age == 1 ? "" : "s")")
                        detailItem(icon: "person.fill", label: "Sex", value: listing.sex)
                        detailItem(icon: "cross.case", label: "Health", value: listing.healthStatus.isEmpty ? "Not specified" : listing.healthStatus)
                        detailItem(icon: "mappin", label: "Location", value: listing.locationName.isEmpty ? "Not specified" : listing.locationName)
                    }

                    // Compatibility
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compatibility")
                            .font(.headline)
                        HStack(spacing: 12) {
                            compatibilityBadge("Kids", good: listing.goodWithKids)
                            compatibilityBadge("Dogs", good: listing.goodWithDogs)
                            compatibilityBadge("Cats", good: listing.goodWithCats)
                        }
                    }

                    // Traits
                    HStack(spacing: 8) {
                        if listing.isNeutered {
                            traitBadge("Neutered", icon: "checkmark.circle.fill")
                        }
                        if listing.isVaccinated {
                            traitBadge("Vaccinated", icon: "syringe.fill")
                        }
                        if listing.isMicrochipped {
                            traitBadge("Microchipped", icon: "barcode")
                        }
                    }

                    // Description
                    if !listing.description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("About")
                                .font(.headline)
                            Text(listing.description)
                                .font(.body)
                        }
                    }

                    // Special needs
                    if let needs = listing.specialNeeds, !needs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Special Needs")
                                .font(.headline)
                            Text(needs)
                                .font(.body)
                                .foregroundColor(.orange)
                        }
                    }

                    // Contact
                    if !listing.contactInfo.isEmpty {
                        Button {
                            // Contact action
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Contact About \(listing.dogName)")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Adoption Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func detailItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.turquoise60)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
    }

    private func compatibilityBadge(_ label: String, good: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: good ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(good ? .green : .red)
            Text(label)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
    }

    private func traitBadge(_ label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.turquoise60)
            Text(label)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.turquoise90))
        .foregroundColor(.turquoise30)
    }
}
