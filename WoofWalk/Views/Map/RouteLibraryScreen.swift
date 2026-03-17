import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct RouteLibraryScreen: View {
    @StateObject private var viewModel = RouteLibraryViewModel()
    @State private var sortOption: RouteSortOption = .recent
    @State private var searchText = ""

    enum RouteSortOption: String, CaseIterable {
        case recent = "Recent"
        case distance = "Distance"
        case name = "Name"
    }

    private var filteredRoutes: [WalkRoute] {
        var routes = viewModel.routes

        if !searchText.isEmpty {
            routes = routes.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.summary.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .recent:
            routes.sort { ($0.updatedAt?.dateValue() ?? .distantPast) > ($1.updatedAt?.dateValue() ?? .distantPast) }
        case .distance:
            routes.sort { $0.distanceMeters > $1.distanceMeters }
        case .name:
            routes.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        }

        return routes
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.routes.isEmpty {
                ProgressView("Loading routes...")
            } else if viewModel.routes.isEmpty {
                emptyState
            } else {
                routeList
            }
        }
        .navigationTitle("Route Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
        }
        .searchable(text: $searchText, prompt: "Search routes")
        .onAppear {
            viewModel.loadRoutes()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "Unknown error")
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No saved routes")
                .font(.title2.bold())
            Text("Save a route after walking or plan one from the map.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var routeList: some View {
        List {
            ForEach(filteredRoutes) { route in
                NavigationLink(value: AppRoute.routeDetail(routeId: route.id ?? "")) {
                    RouteLibraryRow(route: route)
                }
            }
            .onDelete { indexSet in
                let routesToDelete = indexSet.map { filteredRoutes[$0] }
                for route in routesToDelete {
                    if let id = route.id {
                        viewModel.deleteRoute(routeId: id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortOption) {
                ForEach(RouteSortOption.allCases, id: \.self) { option in
                    Label(option.rawValue, systemImage: sortIcon(for: option))
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }

    private func sortIcon(for option: RouteSortOption) -> String {
        switch option {
        case .recent: return "clock"
        case .distance: return "ruler"
        case .name: return "textformat.abc"
        }
    }
}

// MARK: - Route Library Row

struct RouteLibraryRow: View {
    let route: WalkRoute

    private var distanceText: String {
        let km = Double(route.distanceMeters) / 1000.0
        return String(format: "%.1f km", km)
    }

    private var durationText: String {
        let h = route.walkTimeMin / 60
        let m = route.walkTimeMin % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    private var createdText: String {
        guard let date = route.updatedAt?.dateValue() else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var routeTypeBadge: (text: String, color: Color) {
        if route.tags.contains("circular") {
            return ("Circular", .green)
        } else if route.tags.contains("planned") {
            return ("Planned", .orange)
        } else {
            return ("Point-to-Point", .blue)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(route.name.isEmpty ? "Untitled Route" : route.name)
                    .font(.headline)

                Spacer()

                Text(routeTypeBadge.text)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(routeTypeBadge.color.opacity(0.15))
                    .foregroundStyle(routeTypeBadge.color)
                    .clipShape(Capsule())
            }

            if !route.summary.isEmpty {
                Text(route.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label(distanceText, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Label(durationText, systemImage: "clock")
                if !createdText.isEmpty {
                    Label(createdText, systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Route Library ViewModel

@MainActor
class RouteLibraryViewModel: ObservableObject {
    @Published var routes: [WalkRoute] = []
    @Published var selectedRoute: WalkRoute?
    @Published var isLoading = false
    @Published var error: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func loadRoutes() {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "User not authenticated"
            return
        }

        isLoading = true
        listener?.remove()

        listener = db.collection("routes")
            .whereField("createdBy", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    return
                }
                self.routes = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: WalkRoute.self)
                } ?? []
                self.isLoading = false
            }
    }

    func refresh() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        do {
            let snapshot = try await db.collection("routes")
                .whereField("createdBy", isEqualTo: userId)
                .getDocuments()
            routes = snapshot.documents.compactMap { doc in
                try? doc.data(as: WalkRoute.self)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func selectRoute(routeId: String) {
        isLoading = true
        db.collection("routes").document(routeId)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    return
                }
                self.selectedRoute = try? snapshot?.data(as: WalkRoute.self)
                self.isLoading = false
            }
    }

    func deleteRoute(routeId: String) {
        db.collection("routes").document(routeId).delete { [weak self] error in
            if let error = error {
                self?.error = "Failed to delete: \(error.localizedDescription)"
            } else {
                self?.routes.removeAll { $0.id == routeId }
            }
        }
    }

    func clearError() { error = nil }
}
