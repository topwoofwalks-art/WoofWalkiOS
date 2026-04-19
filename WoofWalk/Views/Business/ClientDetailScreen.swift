import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models

enum ClientDetailTab: String, CaseIterable {
    case overview = "Overview"
    case history = "History"
    case invoices = "Invoices"
    case messages = "Messages"
    case notes = "Notes"
}

enum NoteCategory: String, CaseIterable, Codable {
    case general = "General"
    case medical = "Medical"
    case behavioral = "Behavioral"
    case scheduling = "Scheduling"
    case billing = "Billing"
    case important = "Important"

    var icon: String {
        switch self {
        case .general: return "note.text"
        case .medical: return "cross.case.fill"
        case .behavioral: return "pawprint.fill"
        case .scheduling: return "calendar"
        case .billing: return "sterlingsign.circle.fill"
        case .important: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: return .gray
        case .medical: return .red
        case .behavioral: return .orange
        case .scheduling: return .blue
        case .billing: return .purple
        case .important: return .yellow
        }
    }
}

struct ClientNote: Identifiable {
    let id: String
    let content: String
    let category: NoteCategory
    let isPinned: Bool
    let createdAt: Date
    let createdBy: String
}

struct ClientInvoice: Identifiable {
    let id: String
    let invoiceNumber: String
    let date: Date
    let amount: Double
    let isPaid: Bool
}

struct ClientBookingRecord: Identifiable {
    let id: String
    let serviceType: String
    let date: Date
    let status: String
    let price: Double
}

// MARK: - ViewModel

@MainActor
class ClientDetailViewModel: ObservableObject {
    @Published var client: BusinessClient?
    @Published var bookings: [ClientBookingRecord] = []
    @Published var invoices: [ClientInvoice] = []
    @Published var notes: [ClientNote] = []
    @Published var selectedTab: ClientDetailTab = .overview
    @Published var isLoading = true
    @Published var error: String?

    // Stats
    @Published var totalBookings: Int = 0
    @Published var totalSpent: Double = 0
    @Published var averageRating: Double = 0
    @Published var memberSince: Date?

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let clientId: String
    private var listeners: [ListenerRegistration] = []

    init(clientId: String) {
        self.clientId = clientId
        loadClientDetails()
    }

    deinit {
        listeners.forEach { $0.remove() }
    }

    func loadClientDetails() {
        guard let userId = auth.currentUser?.uid else {
            error = "Not signed in"
            isLoading = false
            return
        }

        isLoading = true
        error = nil

        loadClient(userId: userId)
        loadBookings(userId: userId)
        loadInvoices(userId: userId)
        loadNotes(userId: userId)
    }

    private func loadClient(userId: String) {
        let listener = db.collection("organizations")
            .document(userId)
            .collection("clients")
            .document(clientId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error = error {
                    print("[ClientDetail] Error loading client: \(error.localizedDescription)")
                    self.error = "Failed to load client"
                    return
                }

                guard let data = snapshot?.data() else {
                    self.error = "Client not found"
                    return
                }

                let name = data["name"] as? String ?? "Unknown"
                let email = data["email"] as? String ?? ""
                let phone = data["phone"] as? String ?? ""
                let dogs = data["dogs"] as? [String] ?? []
                let isActive = data["isActive"] as? Bool ?? true
                let lastBooking = data["lastBooking"] as? String ?? ""
                let totalWalks = data["totalWalks"] as? Int ?? 0
                let totalSpent = data["totalSpent"] as? Double ?? 0.0
                let notes = data["notes"] as? String ?? ""

                self.client = BusinessClient(
                    id: self.clientId,
                    name: name,
                    email: email,
                    phone: phone,
                    dogs: dogs,
                    isActive: isActive,
                    lastBooking: lastBooking,
                    totalWalks: totalWalks,
                    totalSpent: totalSpent,
                    notes: notes
                )

                self.totalBookings = totalWalks
                self.totalSpent = totalSpent
                self.averageRating = data["averageRating"] as? Double ?? 0.0

                if let ts = data["createdAt"] as? Timestamp {
                    self.memberSince = ts.dateValue()
                } else if let ts = data["memberSince"] as? Timestamp {
                    self.memberSince = ts.dateValue()
                }
            }
        listeners.append(listener)
    }

    private func loadBookings(userId: String) {
        let listener = db.collection("organizations")
            .document(userId)
            .collection("bookings")
            .whereField("clientId", isEqualTo: clientId)
            .order(by: "scheduledDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("[ClientDetail] Error loading bookings: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.bookings = []
                    return
                }

                self.bookings = documents.compactMap { doc in
                    let data = doc.data()
                    let serviceType = data["serviceType"] as? String ?? "Service"
                    let status = data["status"] as? String ?? "pending"
                    let price = data["price"] as? Double ?? 0.0

                    var date = Date()
                    if let ts = data["scheduledDate"] as? Timestamp {
                        date = ts.dateValue()
                    }

                    return ClientBookingRecord(
                        id: doc.documentID,
                        serviceType: serviceType,
                        date: date,
                        status: status,
                        price: price
                    )
                }
            }
        listeners.append(listener)
    }

    private func loadInvoices(userId: String) {
        let listener = db.collection("organizations")
            .document(userId)
            .collection("clients")
            .document(clientId)
            .collection("invoices")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("[ClientDetail] Error loading invoices: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.invoices = []
                    return
                }

                self.invoices = documents.compactMap { doc in
                    let data = doc.data()
                    let number = data["invoiceNumber"] as? String ?? doc.documentID
                    let amount = data["amount"] as? Double ?? 0.0
                    let isPaid = data["isPaid"] as? Bool ?? (data["status"] as? String == "paid")

                    var date = Date()
                    if let ts = data["date"] as? Timestamp {
                        date = ts.dateValue()
                    }

                    return ClientInvoice(
                        id: doc.documentID,
                        invoiceNumber: number,
                        date: date,
                        amount: amount,
                        isPaid: isPaid
                    )
                }
            }
        listeners.append(listener)
    }

    private func loadNotes(userId: String) {
        let listener = db.collection("organizations")
            .document(userId)
            .collection("clients")
            .document(clientId)
            .collection("notes")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("[ClientDetail] Error loading notes: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.notes = []
                    return
                }

                self.notes = documents.compactMap { doc in
                    let data = doc.data()
                    let content = data["content"] as? String ?? ""
                    let categoryStr = data["category"] as? String ?? "general"
                    let category = NoteCategory(rawValue: categoryStr.capitalized) ?? .general
                    let isPinned = data["isPinned"] as? Bool ?? false
                    let createdBy = data["createdBy"] as? String ?? ""

                    var createdAt = Date()
                    if let ts = data["createdAt"] as? Timestamp {
                        createdAt = ts.dateValue()
                    }

                    return ClientNote(
                        id: doc.documentID,
                        content: content,
                        category: category,
                        isPinned: isPinned,
                        createdAt: createdAt,
                        createdBy: createdBy
                    )
                }
            }
        listeners.append(listener)
    }

    // MARK: - Actions

    func addNote(content: String, category: NoteCategory) {
        guard let userId = auth.currentUser?.uid else { return }

        let noteData: [String: Any] = [
            "content": content,
            "category": category.rawValue.lowercased(),
            "isPinned": false,
            "createdAt": FieldValue.serverTimestamp(),
            "createdBy": userId
        ]

        db.collection("organizations")
            .document(userId)
            .collection("clients")
            .document(clientId)
            .collection("notes")
            .addDocument(data: noteData) { error in
                if let error = error {
                    print("[ClientDetail] Error adding note: \(error.localizedDescription)")
                }
            }
    }

    func togglePinNote(_ noteId: String) {
        guard let userId = auth.currentUser?.uid else { return }
        guard let note = notes.first(where: { $0.id == noteId }) else { return }

        db.collection("organizations")
            .document(userId)
            .collection("clients")
            .document(clientId)
            .collection("notes")
            .document(noteId)
            .updateData(["isPinned": !note.isPinned]) { error in
                if let error = error {
                    print("[ClientDetail] Error toggling pin: \(error.localizedDescription)")
                }
            }
    }

    func deleteNote(_ noteId: String) {
        guard let userId = auth.currentUser?.uid else { return }

        db.collection("organizations")
            .document(userId)
            .collection("clients")
            .document(clientId)
            .collection("notes")
            .document(noteId)
            .delete { error in
                if let error = error {
                    print("[ClientDetail] Error deleting note: \(error.localizedDescription)")
                }
            }
    }
}

// MARK: - Main Screen

struct ClientDetailScreen: View {
    let clientId: String
    @StateObject private var viewModel: ClientDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddNote = false

    init(clientId: String) {
        self.clientId = clientId
        _viewModel = StateObject(wrappedValue: ClientDetailViewModel(clientId: clientId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.client == nil {
                ProgressView("Loading client...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMsg = viewModel.error, viewModel.client == nil {
                errorView(errorMsg)
            } else if let client = viewModel.client {
                clientContent(client)
            }
        }
        .navigationTitle(viewModel.client?.name ?? "Client Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(onSave: { content, category in
                viewModel.addNote(content: content, category: category)
                showingAddNote = false
            })
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
            Button("Retry") {
                viewModel.loadClientDetails()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Client Content

    private func clientContent(_ client: BusinessClient) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header card
                clientHeader(client)

                // Contact action buttons
                contactActions(client)

                // Tab picker
                Picker("Tab", selection: $viewModel.selectedTab) {
                    ForEach(ClientDetailTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)

                // Tab content
                tabContent(client)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private func clientHeader(_ client: BusinessClient) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(client.name)
                            .font(.title2.bold())
                        Spacer()
                        statusBadge(isActive: client.isActive)
                    }

                    if !client.email.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "envelope")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(client.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Dogs
                    if !client.dogs.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "pawprint.fill")
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
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Contact Actions

    private func contactActions(_ client: BusinessClient) -> some View {
        HStack(spacing: 12) {
            // Message button (navigate to chat)
            Button {
                AppNavigator.shared.navigate(to: .chatDetail(chatId: client.id))
            } label: {
                Label("Message", systemImage: "message.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            // Email button
            if !client.email.isEmpty {
                Button {
                    if let url = URL(string: "mailto:\(client.email)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Email", systemImage: "envelope.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(_ client: BusinessClient) -> some View {
        switch viewModel.selectedTab {
        case .overview:
            overviewTab(client)
        case .history:
            historyTab
        case .invoices:
            invoicesTab
        case .messages:
            messagesTab(client)
        case .notes:
            notesTab
        }
    }

    // MARK: - Overview Tab

    private func overviewTab(_ client: BusinessClient) -> some View {
        VStack(spacing: 16) {
            // Stats grid
            statsGrid

            // Dogs list
            if !client.dogs.isEmpty {
                dogsSection(client.dogs)
            }

            // Pinned notes
            let pinned = viewModel.notes.filter { $0.isPinned }
            if !pinned.isEmpty {
                pinnedNotesSection(pinned)
            }
        }
        .padding()
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            StatCell(title: "Total Bookings", value: "\(viewModel.totalBookings)", icon: "calendar.badge.checkmark", color: .blue)
            StatCell(title: "Total Spent", value: CurrencyFormatter.shared.formatPrice(viewModel.totalSpent), icon: "sterlingsign.circle.fill", color: .green)
            StatCell(title: "Avg Rating", value: viewModel.averageRating > 0 ? String(format: "%.1f", viewModel.averageRating) : "--", icon: "star.fill", color: .orange)
            StatCell(title: "Member Since", value: memberSinceString, icon: "person.badge.clock", color: .purple)
        }
    }

    private var memberSinceString: String {
        guard let date = viewModel.memberSince else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func dogsSection(_ dogs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dogs")
                .font(.headline)

            ForEach(dogs, id: \.self) { dog in
                HStack(spacing: 10) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                    Text(dog)
                        .font(.body)
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private func pinnedNotesSection(_ notes: [ClientNote]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundColor(.orange)
                Text("Pinned Notes")
                    .font(.headline)
            }

            ForEach(notes) { note in
                noteCard(note)
            }
        }
    }

    // MARK: - History Tab

    private var historyTab: some View {
        Group {
            if viewModel.bookings.isEmpty {
                emptyTabView(icon: "calendar.badge.exclamationmark", message: "No booking history")
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.bookings) { booking in
                        bookingCard(booking)
                    }
                }
                .padding()
            }
        }
    }

    private func bookingCard(_ booking: ClientBookingRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(booking.serviceType)
                    .font(.subheadline.bold())
                Text(formatDate(booking.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.shared.formatPrice(booking.price))
                    .font(.subheadline.bold())
                bookingStatusBadge(booking.status)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func bookingStatusBadge(_ status: String) -> some View {
        let (bgColor, fgColor): (Color, Color) = {
            switch status.lowercased() {
            case "completed": return (Color.green.opacity(0.15), .green)
            case "confirmed", "scheduled": return (Color.blue.opacity(0.15), .blue)
            case "cancelled": return (Color.red.opacity(0.15), .red)
            case "pending": return (Color.orange.opacity(0.15), .orange)
            default: return (Color.gray.opacity(0.15), .gray)
            }
        }()

        return Text(status.capitalized)
            .font(.caption2.bold())
            .foregroundColor(fgColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(bgColor))
    }

    // MARK: - Invoices Tab

    private var invoicesTab: some View {
        Group {
            if viewModel.invoices.isEmpty {
                emptyTabView(icon: "doc.text", message: "No invoices")
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.invoices) { invoice in
                        invoiceCard(invoice)
                    }
                }
                .padding()
            }
        }
    }

    private func invoiceCard(_ invoice: ClientInvoice) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Invoice #\(invoice.invoiceNumber)")
                    .font(.subheadline.bold())
                Text(formatDate(invoice.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.shared.formatPrice(invoice.amount))
                    .font(.subheadline.bold())
                Text(invoice.isPaid ? "Paid" : "Unpaid")
                    .font(.caption2.bold())
                    .foregroundColor(invoice.isPaid ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(invoice.isPaid ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Messages Tab

    private func messagesTab(_ client: BusinessClient) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.top, 40)

            Text("Chat with \(client.name)")
                .font(.headline)

            Text("Open the conversation to send and receive messages.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                AppNavigator.shared.navigate(to: .chatDetail(chatId: client.id))
            } label: {
                Label("Open Chat", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.body.bold())
            }
            .buttonStyle(.borderedProminent)

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Notes Tab

    private var notesTab: some View {
        VStack(spacing: 0) {
            // Add note button row
            HStack {
                Spacer()
                Button {
                    showingAddNote = true
                } label: {
                    Label("Add Note", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            if viewModel.notes.isEmpty {
                emptyTabView(icon: "note.text", message: "No notes yet")
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.notes) { note in
                        noteCard(note)
                            .contextMenu {
                                Button {
                                    viewModel.togglePinNote(note.id)
                                } label: {
                                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin.fill")
                                }

                                Button(role: .destructive) {
                                    viewModel.deleteNote(note.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    private func noteCard(_ note: ClientNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Category badge
                HStack(spacing: 4) {
                    Image(systemName: note.category.icon)
                        .font(.caption2)
                    Text(note.category.rawValue)
                        .font(.caption2.bold())
                }
                .foregroundColor(note.category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(note.category.color.opacity(0.12))
                .cornerRadius(6)

                Text(formatDate(note.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Text(note.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func emptyTabView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
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
                .font(.title3.bold())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}

// MARK: - Add Note Sheet

private struct AddNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var selectedCategory: NoteCategory = .general
    let onSave: (String, NoteCategory) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }

                Section("Category") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(NoteCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.title3)
                                    Text(category.rawValue)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedCategory == category
                                              ? category.color.opacity(0.2)
                                              : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedCategory == category ? category.color : .clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(content, selectedCategory)
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        ClientDetailScreen(clientId: "preview-client")
    }
}
