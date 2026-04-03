import SwiftUI
import FirebaseFirestore

// MARK: - Dog Size Filter

enum DogSizeFilter: String, CaseIterable {
    case all = "All"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var weightRange: ClosedRange<Double> {
        switch self {
        case .all: return 0...200
        case .small: return 0...10
        case .medium: return 10...25
        case .large: return 25...200
        }
    }
}

// MARK: - View Model

@MainActor
class DietPlanViewModel: ObservableObject {
    @Published var dietPlans: [DietPlan] = []
    @Published var sizeFilter: DogSizeFilter = .all
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showAddSheet = false
    @Published var selectedPlan: DietPlan?

    private let db = Firestore.firestore()
    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    var filteredPlans: [DietPlan] {
        if sizeFilter == .all { return dietPlans }
        return dietPlans.filter { sizeFilter.weightRange.contains($0.weightKg) }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts")
                .whereField("type", isEqualTo: CommunityPostType.DIET_PLAN.rawValue)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            dietPlans = posts.compactMap { post -> DietPlan? in
                guard let meta = post.metadata else { return nil }
                return DietPlan(
                    id: post.id,
                    communityId: communityId,
                    postId: post.id ?? "",
                    dogName: meta["dogName"] ?? "",
                    breed: meta["breed"] ?? "",
                    ageYears: Int(meta["ageYears"] ?? "0") ?? 0,
                    weightKg: Double(meta["weightKg"] ?? "0") ?? 0,
                    planName: meta["planName"] ?? post.title,
                    description: post.content,
                    vetApproved: meta["vetApproved"] == "true",
                    vetName: meta["vetName"],
                    createdBy: post.authorId,
                    createdAt: post.createdAt,
                    updatedAt: post.updatedAt
                )
            }
            isLoading = false
        } catch {
            errorMessage = "Failed to load diet plans"
            isLoading = false
        }
    }

    func dogSizeLabel(_ weight: Double) -> String {
        if weight <= 10 { return "Small" }
        if weight <= 25 { return "Medium" }
        return "Large"
    }
}

// MARK: - View

struct DietPlanView: View {
    let communityId: String
    @StateObject private var viewModel: DietPlanViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: DietPlanViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Size filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DogSizeFilter.allCases, id: \.self) { size in
                        Button {
                            viewModel.sizeFilter = size
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: iconForSize(size))
                                    .font(.caption2)
                                Text(size.rawValue)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(viewModel.sizeFilter == size ? Color.turquoise60 : Color(.systemGray6)))
                            .foregroundColor(viewModel.sizeFilter == size ? .white : .primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.filteredPlans.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredPlans) { plan in
                            DietPlanCard(plan: plan, viewModel: viewModel)
                                .onTapGesture { viewModel.selectedPlan = plan }
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
                    Text("Share Plan")
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
        .sheet(item: $viewModel.selectedPlan) { plan in
            DietPlanDetailSheet(plan: plan, viewModel: viewModel)
        }
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("No Diet Plans")
                .font(.headline)
            Text("Share your dog's diet plan to help other owners in the community")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                viewModel.showAddSheet = true
            } label: {
                Label("Share a Diet Plan", systemImage: "plus.circle")
                    .font(.subheadline.bold())
                    .foregroundColor(.turquoise60)
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding()
    }

    private func iconForSize(_ size: DogSizeFilter) -> String {
        switch size {
        case .all: return "pawprint.fill"
        case .small: return "hare"
        case .medium: return "dog"
        case .large: return "dog.fill"
        }
    }
}

// MARK: - Diet Plan Card

private struct DietPlanCard: View {
    let plan: DietPlan
    let viewModel: DietPlanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.planName)
                        .font(.headline)
                        .lineLimit(1)
                    if !plan.breed.isEmpty {
                        Text(plan.breed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if plan.vetApproved {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                        Text("Vet Approved")
                            .font(.caption2)
                    }
                    .foregroundColor(.green)
                }
            }

            // Dog info chips
            HStack(spacing: 8) {
                if plan.weightKg > 0 {
                    infoChip(icon: "scalemass", text: String(format: "%.1f kg", plan.weightKg))
                }
                if plan.weightKg > 0 {
                    infoChip(icon: "ruler", text: viewModel.dogSizeLabel(plan.weightKg))
                }
                if plan.ageYears > 0 {
                    infoChip(icon: "calendar", text: "\(plan.ageYears) year\(plan.ageYears == 1 ? "" : "s")")
                }
            }

            // Description preview
            if !plan.description.isEmpty {
                Text(plan.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Meal count
            if !plan.meals.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(plan.meals.count) meal\(plan.meals.count == 1 ? "" : "s") per day")
                        .font(.caption)
                }
                .foregroundColor(.turquoise60)
            }

            // Allergies
            if !plan.allergies.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                    Text("Allergies: \(plan.allergies.joined(separator: ", "))")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.orange)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.06), radius: 4, y: 2))
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(.systemGray6)))
        .foregroundColor(.secondary)
    }
}

// MARK: - Diet Plan Detail Sheet

private struct DietPlanDetailSheet: View {
    let plan: DietPlan
    let viewModel: DietPlanViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title & badge
                    HStack {
                        Text(plan.planName)
                            .font(.title2.bold())
                        Spacer()
                        if plan.vetApproved {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Vet Approved")
                                    .fontWeight(.medium)
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.green.opacity(0.1)))
                        }
                    }

                    if let vetName = plan.vetName, !vetName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "stethoscope")
                            Text("Approved by \(vetName)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    // Dog info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dog Profile")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            dogInfoItem(icon: "pawprint.fill", label: "Name", value: plan.dogName.isEmpty ? "N/A" : plan.dogName)
                            dogInfoItem(icon: "dog", label: "Breed", value: plan.breed.isEmpty ? "N/A" : plan.breed)
                            dogInfoItem(icon: "scalemass", label: "Weight", value: plan.weightKg > 0 ? String(format: "%.1f kg", plan.weightKg) : "N/A")
                            dogInfoItem(icon: "calendar", label: "Age", value: plan.ageYears > 0 ? "\(plan.ageYears) years" : "N/A")
                        }
                    }

                    // Description
                    if !plan.description.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.headline)
                            Text(plan.description)
                                .font(.body)
                        }
                    }

                    // Meal schedule
                    if !plan.meals.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Meal Schedule")
                                .font(.headline)
                            ForEach(Array(plan.meals.enumerated()), id: \.offset) { _, meal in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.turquoise60)
                                        Text(meal.name)
                                            .font(.subheadline.bold())
                                        Spacer()
                                        if !meal.time.isEmpty {
                                            Text(meal.time)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    if meal.portionGrams > 0 {
                                        Text("Portion: \(Int(meal.portionGrams))g")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    if !meal.ingredients.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 6) {
                                                ForEach(meal.ingredients, id: \.self) { ingredient in
                                                    Text(ingredient)
                                                        .font(.caption)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Capsule().fill(Color.turquoise90))
                                                        .foregroundColor(.turquoise30)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                            }
                        }
                    }

                    // Supplements
                    if !plan.supplements.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Supplements")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(plan.supplements, id: \.self) { supplement in
                                        HStack(spacing: 4) {
                                            Image(systemName: "pills.fill")
                                                .font(.caption2)
                                            Text(supplement)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Color(.systemGray6)))
                                    }
                                }
                            }
                        }
                    }

                    // Allergies
                    if !plan.allergies.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Allergies & Sensitivities")
                                    .font(.headline)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(plan.allergies, id: \.self) { allergy in
                                        Text(allergy)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Diet Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func dogInfoItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.turquoise60)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
    }
}
