import SwiftUI

struct BusinessClientsScreen: View {
    @ObservedObject var viewModel: BusinessViewModel
    @State private var searchText: String = ""
    @State private var showingAddClient: Bool = false
    @State private var showingSortOptions: Bool = false
    @State private var showingFilterOptions: Bool = false
    @State private var showingImport: Bool = false
    @State private var showingExportShare: Bool = false
    @State private var exportFileURL: URL?
    @State private var sortOrder: ClientSortOrder = .name
    @State private var filterMode: ClientFilterMode = .all

    private enum ClientSortOrder: String, CaseIterable {
        case name = "Name"
        case recent = "Recent"
        case ltv = "Lifetime Value"
    }

    private enum ClientFilterMode: String, CaseIterable {
        case all = "All Clients"
        case active = "Active Only"
        case inactive = "Inactive Only"
    }

    private var filteredClients: [BusinessClient] {
        var clients = viewModel.clients

        // Apply filter
        switch filterMode {
        case .all: break
        case .active: clients = clients.filter { $0.isActive }
        case .inactive: clients = clients.filter { !$0.isActive }
        }

        // Apply search
        if !searchText.isEmpty {
            clients = clients.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText) ||
                $0.dogs.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sort
        switch sortOrder {
        case .name: return clients.sorted { $0.name < $1.name }
        case .recent: return clients
        case .ltv: return clients.sorted { $0.totalSpent > $1.totalSpent }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 16) {
                    // Search bar
                    searchBar

                    // 2x2 Stats grid
                    statsGrid

                    // Client list or empty state
                    if viewModel.isLoading && viewModel.clients.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if filteredClients.isEmpty {
                        emptyState
                    } else {
                        clientList
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground))

            // FAB
            addClientButton
        }
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingSortOptions = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }

                Button {
                    showingFilterOptions = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }

                Menu {
                    Button {
                        showingImport = true
                    } label: {
                        Label("Import Clients", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        if let url = viewModel.exportClientsCSV() {
                            exportFileURL = url
                            showingExportShare = true
                        }
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.clients.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingImport) {
            ClientImportScreen(viewModel: viewModel)
        }
        .sheet(isPresented: $showingExportShare) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
        .confirmationDialog("Sort By", isPresented: $showingSortOptions) {
            ForEach(ClientSortOrder.allCases, id: \.self) { order in
                Button(order.rawValue) {
                    sortOrder = order
                }
            }
        }
        .confirmationDialog("Filter", isPresented: $showingFilterOptions) {
            ForEach(ClientFilterMode.allCases, id: \.self) { mode in
                Button(mode.rawValue) {
                    filterMode = mode
                }
            }
        }
        .alert("Add Client", isPresented: $showingAddClient) {
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Client invitations will be available in a future update.")
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search clients...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .cornerRadius(12)
        .padding(.top, 4)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ClientStatCard(title: "Total Clients", value: "\(viewModel.totalClients)", icon: "person.2.fill", color: .blue)
            ClientStatCard(title: "Active", value: String(format: "%.1f%%", viewModel.activePercentage), icon: "checkmark.circle.fill", color: .green)
            ClientStatCard(title: "Avg LTV", value: CurrencyFormatter.shared.formatPrice(viewModel.averageLTV), icon: "sterlingsign.circle.fill", color: .purple)
            ClientStatCard(title: "Churn Rate", value: String(format: "%.1f%%", viewModel.churnRate), icon: "arrow.down.right", color: .orange)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            Image(systemName: "person.2.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Clients")
                .font(.title2.bold())

            Text(searchText.isEmpty
                 ? "Your client list is empty.\nInvite clients to get started."
                 : "No clients match your search.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Client List

    private var clientList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Clients (\(filteredClients.count))")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 8)

            ForEach(filteredClients) { client in
                Button {
                    AppNavigator.shared.navigate(to: .businessClientDetail(clientId: client.id))
                } label: {
                    clientRow(client)
                }
                .buttonStyle(.plain)
                if client.id != filteredClients.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func clientRow(_ client: BusinessClient) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Image(systemName: "person.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(client.name)
                        .font(.body.bold())
                    Spacer()
                    statusBadge(isActive: client.isActive)
                }
                Text(client.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Dogs
                HStack(spacing: 6) {
                    Image(systemName: "pawprint")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ForEach(client.dogs, id: \.self) { dog in
                        Text(dog)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func statusBadge(isActive: Bool) -> some View {
        Text(isActive ? "Active" : "Inactive")
            .font(.caption2.bold())
            .foregroundColor(isActive ? .green : .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
            )
    }

    // MARK: - FAB

    private var addClientButton: some View {
        Button {
            showingAddClient = true
        } label: {
            Image(systemName: "person.badge.plus")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.turquoise60)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Client Stat Card

private struct ClientStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Spacer()
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}

#Preview {
    NavigationStack {
        BusinessClientsScreen(viewModel: BusinessViewModel())
    }
}
