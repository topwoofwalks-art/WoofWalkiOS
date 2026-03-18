import SwiftUI

struct BusinessClientsScreen: View {
    @State private var searchText: String = ""
    @State private var sortOrder: ClientSortOrder = .name
    @State private var showingAddClient: Bool = false

    private enum ClientSortOrder: String, CaseIterable {
        case name = "Name"
        case recent = "Recent"
        case dogs = "Dogs"
    }

    private var filteredClients: [BusinessClient] {
        let clients = sampleClients
        let filtered = searchText.isEmpty
            ? clients
            : clients.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.dogs.joined(separator: " ").localizedCaseInsensitiveContains(searchText) }

        switch sortOrder {
        case .name: return filtered.sorted { $0.name < $1.name }
        case .recent: return filtered
        case .dogs: return filtered.sorted { $0.dogs.count > $1.dogs.count }
        }
    }

    var body: some View {
        List {
            // Stats header
            Section {
                statsHeader
            }

            // Sort picker
            Section {
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(ClientSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            // Client list
            if filteredClients.isEmpty {
                Section {
                    emptyState
                }
            } else {
                Section("Clients (\(filteredClients.count))") {
                    ForEach(filteredClients) { client in
                        clientRow(client)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search clients or dogs")
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddClient = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .alert("Add Client", isPresented: $showingAddClient) {
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Client invitations will be available in a future update.")
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statItem(value: "\(sampleClients.count)", label: "Total", icon: "person.2.fill", color: .blue)
            Divider().frame(height: 40)
            statItem(value: "\(sampleClients.filter { $0.isActive }.count)", label: "Active", icon: "checkmark.circle", color: .green)
            Divider().frame(height: 40)
            let totalDogs = sampleClients.reduce(0) { $0 + $1.dogs.count }
            statItem(value: "\(totalDogs)", label: "Dogs", icon: "pawprint.fill", color: .orange)
        }
        .listRowBackground(Color.clear)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Client Row

    private func clientRow(_ client: BusinessClient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.name)
                        .font(.body.bold())
                    Text(client.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(client.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            // Dogs
            HStack(spacing: 6) {
                Image(systemName: "pawprint")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(client.dogs, id: \.self) { dog in
                    Text(dog)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            // Last booking info
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Last booking: \(client.lastBooking)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(client.totalWalks) walks")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if !client.notes.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(client.notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Clients Found")
                .font(.headline)
            Text(searchText.isEmpty
                 ? "Your client list is empty. Invite clients to get started."
                 : "No clients match your search.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }

    // MARK: - Sample Data

    private var sampleClients: [BusinessClient] {
        [
            BusinessClient(id: "1", name: "Sarah Thompson", email: "sarah@email.com", dogs: ["Bella"], isActive: true, lastBooking: "Today", totalWalks: 24, notes: "Prefers morning walks"),
            BusinessClient(id: "2", name: "Tom Wilson", email: "tom@email.com", dogs: ["Max", "Charlie"], isActive: true, lastBooking: "Yesterday", totalWalks: 18, notes: ""),
            BusinessClient(id: "3", name: "Emma Clarke", email: "emma@email.com", dogs: ["Luna", "Daisy"], isActive: true, lastBooking: "3 days ago", totalWalks: 31, notes: "Group walks preferred"),
            BusinessClient(id: "4", name: "James Miller", email: "james@email.com", dogs: ["Rocky"], isActive: false, lastBooking: "2 weeks ago", totalWalks: 8, notes: "On holiday until April"),
            BusinessClient(id: "5", name: "Lucy Brown", email: "lucy@email.com", dogs: ["Poppy"], isActive: true, lastBooking: "Today", totalWalks: 12, notes: ""),
        ]
    }
}

// MARK: - Business Client Model

private struct BusinessClient: Identifiable {
    let id: String
    let name: String
    let email: String
    let dogs: [String]
    let isActive: Bool
    let lastBooking: String
    let totalWalks: Int
    let notes: String
}
