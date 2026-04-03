import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Alert Severity

enum AlertSeverity: String, CaseIterable {
    case URGENT
    case WARNING
    case INFO

    var color: Color {
        switch self {
        case .URGENT: return .red
        case .WARNING: return Color(red: 0.95, green: 0.6, blue: 0.07) // amber
        case .INFO: return .blue
        }
    }

    var icon: String {
        switch self {
        case .URGENT: return "exclamationmark.octagon.fill"
        case .WARNING: return "exclamationmark.triangle.fill"
        case .INFO: return "info.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .URGENT: return "Urgent"
        case .WARNING: return "Warning"
        case .INFO: return "Info"
        }
    }

    var sortOrder: Int {
        switch self {
        case .URGENT: return 0
        case .WARNING: return 1
        case .INFO: return 2
        }
    }
}

// MARK: - View Model

@MainActor
class BreedAlertsViewModel: ObservableObject {
    @Published var alerts: [BreedAlert] = []
    @Published var selectedFilter: String = "All"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCreateSheet = false
    @Published var isAdmin = false

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    let communityId: String

    init(communityId: String) {
        self.communityId = communityId
    }

    static let filterOptions = ["All", "URGENT", "WARNING", "INFO"]

    var filteredAlerts: [BreedAlert] {
        let source: [BreedAlert]
        if selectedFilter == "All" {
            source = alerts
        } else {
            source = alerts.filter { $0.severity == selectedFilter }
        }
        // Sort by severity (urgent first), then by date
        return source.sorted { a, b in
            let aSeverity = AlertSeverity(rawValue: a.severity)?.sortOrder ?? 3
            let bSeverity = AlertSeverity(rawValue: b.severity)?.sortOrder ?? 3
            if aSeverity != bSeverity { return aSeverity < bSeverity }
            return a.createdAt > b.createdAt
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await db.collection("communities").document(communityId)
                .collection("posts")
                .whereField("type", isEqualTo: CommunityPostType.BREED_ALERT.rawValue)
                .whereField("isDeleted", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            let posts = snapshot.documents.compactMap { try? $0.data(as: CommunityPost.self) }
            alerts = posts.compactMap { post -> BreedAlert? in
                guard let meta = post.metadata else { return nil }
                return BreedAlert(
                    id: post.id,
                    communityId: communityId,
                    postId: post.id ?? "",
                    breed: meta["breed"] ?? "",
                    alertType: meta["alertType"] ?? "",
                    title: post.title,
                    description: post.content,
                    severity: meta["severity"] ?? "INFO",
                    sourceUrl: meta["sourceUrl"],
                    isVerified: meta["verified"] == "true",
                    createdBy: post.authorId,
                    createdAt: post.createdAt
                )
            }

            // Check admin status
            if let uid = auth.currentUser?.uid {
                let memberDoc = try? await db.collection("communities").document(communityId)
                    .collection("members").document(uid).getDocument()
                if let member = try? memberDoc?.data(as: CommunityMember.self) {
                    isAdmin = member.canModerate()
                }
            }

            isLoading = false
        } catch {
            errorMessage = "Failed to load alerts"
            isLoading = false
        }
    }

    func severityEnum(_ severity: String) -> AlertSeverity {
        AlertSeverity(rawValue: severity) ?? .INFO
    }
}

// MARK: - View

struct BreedAlertsView: View {
    let communityId: String
    @StateObject private var viewModel: BreedAlertsViewModel

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: BreedAlertsViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BreedAlertsViewModel.filterOptions, id: \.self) { filter in
                        Button {
                            viewModel.selectedFilter = filter
                        } label: {
                            HStack(spacing: 4) {
                                if filter != "All", let severity = AlertSeverity(rawValue: filter) {
                                    Image(systemName: severity.icon)
                                        .font(.caption2)
                                }
                                Text(filter == "All" ? "All" : (AlertSeverity(rawValue: filter)?.displayName ?? filter))
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(viewModel.selectedFilter == filter
                                    ? (filter == "All" ? Color.turquoise60 : (AlertSeverity(rawValue: filter)?.color ?? .turquoise60))
                                    : Color(.systemGray6))
                            )
                            .foregroundColor(viewModel.selectedFilter == filter ? .white : .primary)
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
            } else if viewModel.filteredAlerts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.filteredAlerts) { alert in
                            BreedAlertCard(alert: alert, severity: viewModel.severityEnum(alert.severity))
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.load() }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isAdmin {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Post Alert")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.red))
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .padding()
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreateCommunityPostSheet(communityId: communityId) {
                Task { await viewModel.load() }
            }
        }
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 56))
                .foregroundColor(.green)
            Text("No Active Alerts")
                .font(.headline)
            Text("All clear! No breed-specific health alerts or warnings at this time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Breed Alert Card

private struct BreedAlertCard: View {
    let alert: BreedAlert
    let severity: AlertSeverity

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Severity bar
            Rectangle()
                .fill(severity.color)
                .frame(height: 4)

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: severity.icon)
                        .foregroundColor(severity.color)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.subheadline.bold())
                            .lineLimit(isExpanded ? nil : 2)

                        HStack(spacing: 8) {
                            Text(severity.displayName)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(severity.color.opacity(0.15)))
                                .foregroundColor(severity.color)

                            if !alert.breed.isEmpty {
                                Text(alert.breed)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if alert.isVerified {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption2)
                                    Text("Verified")
                                        .font(.caption2)
                                }
                                .foregroundColor(.turquoise60)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if isExpanded {
                    // Description
                    if !alert.description.isEmpty {
                        Text(alert.description)
                            .font(.body)
                    }

                    // Affected regions
                    if !alert.affectedRegions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Affected Regions")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(alert.affectedRegions, id: \.self) { region in
                                        Text(region)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color(.systemGray6)))
                                    }
                                }
                            }
                        }
                    }

                    // Source
                    if let source = alert.sourceUrl, !source.isEmpty {
                        Link(destination: URL(string: source) ?? URL(string: "https://example.com")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                Text("View Source")
                            }
                            .font(.caption)
                            .foregroundColor(.turquoise60)
                        }
                    }
                }

                // Date
                Text(formatDate(alert.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(color: .black.opacity(0.06), radius: 4, y: 2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
