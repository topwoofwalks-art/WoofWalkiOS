import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Model

struct BusinessConversation: Identifiable {
    let id: String
    let clientId: String
    let name: String
    let lastMessage: String
    let timestamp: Date?
    let avatarURL: String?
    let isRead: Bool
    let unreadCount: Int
    let isPinned: Bool
    let isArchived: Bool

    init(id: String, clientId: String = "", name: String, lastMessage: String, timestamp: Date? = nil, avatarURL: String? = nil, isRead: Bool = true, unreadCount: Int = 0, isPinned: Bool = false, isArchived: Bool = false) {
        self.id = id; self.clientId = clientId; self.name = name; self.lastMessage = lastMessage
        self.timestamp = timestamp; self.avatarURL = avatarURL; self.isRead = isRead
        self.unreadCount = unreadCount; self.isPinned = isPinned; self.isArchived = isArchived
    }

    var formattedTimestamp: String {
        guard let ts = timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: ts)
    }
}

// MARK: - ViewModel

@MainActor
class BusinessInboxViewModel: ObservableObject {
    @Published var conversations: [BusinessConversation] = []
    @Published var isLoading: Bool = false
    @Published var isAwayMode: Bool = false
    @Published var awayMessage: AutoReply = AutoReply()
    @Published var holidayMode: HolidayMode = HolidayMode()
    @Published var quickReplies: [QuickReplyTemplate] = QuickReplyTemplate.defaults
    @Published var showArchived: Bool = false
    @Published var toastMessage: String?
    @Published var error: String?

    private let db = Firestore.firestore()
    private var conversationListener: ListenerRegistration?
    private var profileListener: ListenerRegistration?
    private var organizationId: String?

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    func loadData() {
        guard let userId = currentUserId else { return }
        isLoading = true
        loadOrganizationId(userId: userId)
        listenToConversations(userId: userId)
    }

    func cleanup() {
        conversationListener?.remove()
        profileListener?.remove()
        conversationListener = nil
        profileListener = nil
    }

    // MARK: - Organization & Profile

    private func loadOrganizationId(userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self else { return }
            Task { @MainActor in
                let orgId = snapshot?.data()?["organizationId"] as? String ?? userId
                self.organizationId = orgId
                self.listenToBusinessProfile(orgId: orgId)
                self.loadQuickReplies(orgId: orgId)
            }
        }
    }

    private func listenToBusinessProfile(orgId: String) {
        profileListener?.remove()
        profileListener = db.collection("businessProfiles").document(orgId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("[BusinessInbox] Profile listener error: \(error.localizedDescription)")
                    return
                }
                guard let data = snapshot?.data() else { return }

                Task { @MainActor in
                    // Parse away message
                    let awayData = data["awayMessage"] as? [String: Any] ?? [:]
                    self.awayMessage = AutoReply(
                        enabled: awayData["enabled"] as? Bool ?? false,
                        message: awayData["message"] as? String ?? "Thanks for your message! I'm currently away and will respond within 24 hours.",
                        autoReplyEnabled: awayData["autoReplyEnabled"] as? Bool ?? true
                    )
                    self.isAwayMode = self.awayMessage.enabled

                    // Parse holiday mode
                    let holidayData = data["holidayMode"] as? [String: Any] ?? [:]
                    self.holidayMode = HolidayMode(
                        enabled: holidayData["enabled"] as? Bool ?? false,
                        startDate: (holidayData["startDate"] as? Timestamp)?.dateValue(),
                        endDate: (holidayData["endDate"] as? Timestamp)?.dateValue(),
                        message: holidayData["message"] as? String ?? ""
                    )
                }
            }
    }

    // MARK: - Conversations

    private func listenToConversations(userId: String) {
        conversationListener?.remove()
        conversationListener = db.collection("messageThreads")
            .whereField("participantIds", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("[BusinessInbox] Conversations listener error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isLoading = false
                        self.error = error.localizedDescription
                    }
                    return
                }

                let convos = snapshot?.documents.compactMap { doc -> BusinessConversation? in
                    let data = doc.data()
                    let participants = data["participantIds"] as? [String] ?? []
                    let participantNames = data["participantNames"] as? [String: String] ?? [:]
                    let participantAvatars = data["participantAvatars"] as? [String: String] ?? [:]
                    let unreadCountMap = data["unreadCount"] as? [String: Any] ?? [:]

                    let otherUserId = participants.first(where: { $0 != userId })
                    let clientName = otherUserId.flatMap { participantNames[$0] } ?? "Unknown Client"
                    let clientPhoto = otherUserId.flatMap { participantAvatars[$0] }
                    let unreadCount: Int
                    if let count = unreadCountMap[userId] as? Int {
                        unreadCount = count
                    } else if let count = unreadCountMap[userId] as? Int64 {
                        unreadCount = Int(count)
                    } else {
                        unreadCount = 0
                    }

                    return BusinessConversation(
                        id: doc.documentID,
                        clientId: otherUserId ?? "",
                        name: clientName,
                        lastMessage: data["lastMessage"] as? String ?? "",
                        timestamp: (data["lastMessageAt"] as? Timestamp)?.dateValue(),
                        avatarURL: clientPhoto,
                        isRead: unreadCount == 0,
                        unreadCount: unreadCount,
                        isPinned: data["isPinned"] as? Bool ?? false,
                        isArchived: data["isArchived"] as? Bool ?? false
                    )
                } ?? []

                Task { @MainActor in
                    self.conversations = convos
                    self.isLoading = false
                }
            }
    }

    var filteredConversations: [BusinessConversation] {
        conversations
            .filter { showArchived || !$0.isArchived }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                let lhsTime = lhs.timestamp?.timeIntervalSince1970 ?? 0
                let rhsTime = rhs.timestamp?.timeIntervalSince1970 ?? 0
                return lhsTime > rhsTime
            }
    }

    // MARK: - Away Mode Toggle

    func toggleAwayMode() {
        guard let orgId = organizationId else {
            error = "Business profile not loaded yet. Try again."
            return
        }

        let newEnabled = !awayMessage.enabled
        let data: [String: Any] = [
            "enabled": newEnabled,
            "message": awayMessage.message,
            "autoReplyEnabled": awayMessage.autoReplyEnabled
        ]

        // Write to both businessProfiles and organizations (matching Android)
        let batch = db.batch()
        let profileRef = db.collection("businessProfiles").document(orgId)
        let orgRef = db.collection("organizations").document(orgId)

        batch.setData(["awayMessage": data], forDocument: profileRef, merge: true)
        batch.setData(["awayMessage": data], forDocument: orgRef, merge: true)

        batch.commit { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.error = "Failed to update away mode: \(error.localizedDescription)"
                } else {
                    self.toastMessage = newEnabled ? "Away mode enabled" : "Away mode disabled"
                }
            }
        }
    }

    // MARK: - Holiday Mode

    func saveHolidayMode() {
        guard let orgId = organizationId else { return }

        var data: [String: Any] = [
            "enabled": holidayMode.enabled,
            "message": holidayMode.message
        ]
        if let start = holidayMode.startDate {
            data["startDate"] = Timestamp(date: start)
        }
        if let end = holidayMode.endDate {
            data["endDate"] = Timestamp(date: end)
        }

        let batch = db.batch()
        let profileRef = db.collection("businessProfiles").document(orgId)
        let orgRef = db.collection("organizations").document(orgId)

        batch.setData(["holidayMode": data], forDocument: profileRef, merge: true)
        batch.setData(["holidayMode": data], forDocument: orgRef, merge: true)

        batch.commit { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.error = "Failed to update holiday mode: \(error.localizedDescription)"
                } else {
                    self.toastMessage = self.holidayMode.enabled ? "Holiday mode enabled" : "Holiday mode disabled"
                }
            }
        }
    }

    // MARK: - Save Away Settings (from settings view)

    func saveAwaySettings(awayEnabled: Bool, awayMsg: String, holiday: HolidayMode, replies: [QuickReplyTemplate]) {
        guard let orgId = organizationId else { return }

        // Save away message
        let awayData: [String: Any] = [
            "enabled": awayEnabled,
            "message": awayMsg,
            "autoReplyEnabled": true
        ]

        // Save holiday mode
        var holidayData: [String: Any] = [
            "enabled": holiday.enabled,
            "message": holiday.message
        ]
        if let start = holiday.startDate {
            holidayData["startDate"] = Timestamp(date: start)
        }
        if let end = holiday.endDate {
            holidayData["endDate"] = Timestamp(date: end)
        }

        let mergeData: [String: Any] = [
            "awayMessage": awayData,
            "holidayMode": holidayData
        ]

        let batch = db.batch()
        let profileRef = db.collection("businessProfiles").document(orgId)
        let orgRef = db.collection("organizations").document(orgId)

        batch.setData(mergeData, forDocument: profileRef, merge: true)
        batch.setData(mergeData, forDocument: orgRef, merge: true)

        batch.commit { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.error = "Failed to save settings: \(error.localizedDescription)"
                } else {
                    self.toastMessage = "Settings saved"
                }
            }
        }

        // Save quick replies
        saveQuickReplies(orgId: orgId, replies: replies)
    }

    // MARK: - Quick Replies Firestore

    private func loadQuickReplies(orgId: String) {
        db.collection("businessProfiles").document(orgId).collection("quickReplies")
            .order(by: "category")
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("[BusinessInbox] Quick replies load error: \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents, !docs.isEmpty else { return }

                let replies = docs.compactMap { doc -> QuickReplyTemplate? in
                    let data = doc.data()
                    guard let text = data["text"] as? String else { return nil }
                    return QuickReplyTemplate(
                        id: doc.documentID,
                        text: text,
                        category: data["category"] as? String ?? "General"
                    )
                }

                Task { @MainActor in
                    if !replies.isEmpty {
                        self.quickReplies = replies
                    }
                }
            }
    }

    private func saveQuickReplies(orgId: String, replies: [QuickReplyTemplate]) {
        let collection = db.collection("businessProfiles").document(orgId).collection("quickReplies")

        // Delete existing then write new
        collection.getDocuments { snapshot, _ in
            let batch = self.db.batch()
            snapshot?.documents.forEach { batch.deleteDocument($0.reference) }

            for reply in replies {
                let ref = collection.document(reply.id)
                batch.setData([
                    "text": reply.text,
                    "category": reply.category
                ], forDocument: ref)
            }

            batch.commit { error in
                if let error {
                    print("[BusinessInbox] Failed to save quick replies: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Pin / Archive / Mark Read

    func pinConversation(chatId: String) {
        let isPinned = conversations.first(where: { $0.id == chatId })?.isPinned ?? false
        db.collection("messageThreads").document(chatId).updateData([
            "isPinned": !isPinned
        ]) { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.error = "Failed to update pin: \(error.localizedDescription)"
                } else {
                    self.toastMessage = isPinned ? "Conversation unpinned" : "Conversation pinned"
                }
            }
        }
    }

    func archiveConversation(chatId: String) {
        let isArchived = conversations.first(where: { $0.id == chatId })?.isArchived ?? false
        db.collection("messageThreads").document(chatId).updateData([
            "isArchived": !isArchived
        ]) { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.error = "Failed to update archive: \(error.localizedDescription)"
                } else {
                    self.toastMessage = isArchived ? "Conversation unarchived" : "Conversation archived"
                }
            }
        }
    }

    func markAsRead(chatId: String) {
        guard let userId = currentUserId else { return }
        db.collection("messageThreads").document(chatId).updateData([
            "unreadCount.\(userId)": 0
        ])
    }

    func markAllAsRead() {
        guard let userId = currentUserId else { return }
        let unreadConversations = conversations.filter { $0.unreadCount > 0 }
        guard !unreadConversations.isEmpty else { return }

        let batch = db.batch()
        for convo in unreadConversations {
            let ref = db.collection("messageThreads").document(convo.id)
            batch.updateData(["unreadCount.\(userId)": 0], forDocument: ref)
        }
        batch.commit { [weak self] error in
            Task { @MainActor in
                if error == nil {
                    self?.toastMessage = "All conversations marked as read"
                }
            }
        }
    }
}

// MARK: - Business Inbox Screen

struct BusinessInboxScreen: View {
    @StateObject private var viewModel = BusinessInboxViewModel()
    @State private var searchText: String = ""
    @State private var showSearch: Bool = false
    @State private var selectedConversationId: String?
    @State private var showAwaySettings: Bool = false

    // Local editing copies for away settings sheet
    @State private var editAwayEnabled: Bool = false
    @State private var editAwayMessage: String = ""
    @State private var editStartDate: Date = Date()
    @State private var editEndDate: Date = Date().addingTimeInterval(86400)
    @State private var editHolidayMode: HolidayMode = HolidayMode()
    @State private var editQuickReplies: [QuickReplyTemplate] = QuickReplyTemplate.defaults

    var filteredConversations: [BusinessConversation] {
        let base = viewModel.filteredConversations
        if searchText.isEmpty { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.lastMessage.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status banners
                statusBanners

                // Search bar
                if showSearch {
                    searchBar
                }

                // Conversation list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading conversations...")
                        .foregroundColor(.gray)
                    Spacer()
                } else if filteredConversations.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No conversations yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                selectedConversationId: $selectedConversationId,
                                onPin: { viewModel.pinConversation(chatId: conversation.id) },
                                onArchive: { viewModel.archiveConversation(chatId: conversation.id) },
                                onMarkRead: { viewModel.markAsRead(chatId: conversation.id) }
                            )
                            .listRowBackground(Color(.systemBackground).opacity(0.05))
                            .listRowSeparatorTint(Color.white.opacity(0.1))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.black)
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Away mode toggle
                        Button {
                            viewModel.toggleAwayMode()
                        } label: {
                            Image(systemName: viewModel.isAwayMode ? "moon.fill" : "moon")
                                .foregroundColor(viewModel.isAwayMode ? .orange : .white)
                        }

                        // Search toggle
                        Button {
                            withAnimation {
                                showSearch.toggle()
                                if !showSearch { searchText = "" }
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                        }

                        // Overflow menu
                        Menu {
                            Button {
                                viewModel.markAllAsRead()
                            } label: {
                                Label("Mark all as read", systemImage: "checkmark.circle")
                            }
                            Button {
                                viewModel.showArchived.toggle()
                            } label: {
                                Label(
                                    viewModel.showArchived ? "Hide archived" : "Show archived",
                                    systemImage: viewModel.showArchived ? "archivebox.fill" : "archivebox"
                                )
                            }
                            Button {
                                prepareAwaySettingsEdit()
                                showAwaySettings = true
                            } label: {
                                Label("Away & Holiday Settings", systemImage: "gear")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showAwaySettings) {
                NavigationStack {
                    AwayModeSettingsView(
                        isEnabled: $editAwayEnabled,
                        autoReplyMessage: $editAwayMessage,
                        startDate: $editStartDate,
                        endDate: $editEndDate,
                        holidayMode: $editHolidayMode,
                        quickReplies: $editQuickReplies,
                        onSave: {
                            viewModel.saveAwaySettings(
                                awayEnabled: editAwayEnabled,
                                awayMsg: editAwayMessage,
                                holiday: editHolidayMode,
                                replies: editQuickReplies
                            )
                        }
                    )
                }
                .preferredColorScheme(.dark)
            }
            .overlay(alignment: .bottom) {
                if let toast = viewModel.toastMessage {
                    Text(toast)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { viewModel.toastMessage = nil }
                            }
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.loadData() }
        .onDisappear { viewModel.cleanup() }
    }

    // MARK: - Status Banners

    @ViewBuilder
    private var statusBanners: some View {
        if viewModel.isAwayMode {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .foregroundColor(.orange)
                Text("You're in away mode. Auto-replies are enabled.")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.2))
        }

        if viewModel.holidayMode.isCurrentlyActive {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Holiday mode active")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    if let end = viewModel.holidayMode.endDate {
                        Text("Until \(end.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.yellow.opacity(0.15))
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search conversations", text: $searchText)
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Prepare Edit

    private func prepareAwaySettingsEdit() {
        editAwayEnabled = viewModel.awayMessage.enabled
        editAwayMessage = viewModel.awayMessage.message
        editHolidayMode = viewModel.holidayMode
        editStartDate = viewModel.holidayMode.startDate ?? Date()
        editEndDate = viewModel.holidayMode.endDate ?? Date().addingTimeInterval(86400)
        editQuickReplies = viewModel.quickReplies
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: BusinessConversation
    @Binding var selectedConversationId: String?
    var onPin: () -> Void = {}
    var onArchive: () -> Void = {}
    var onMarkRead: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            // Pinned indicator + avatar
            ZStack(alignment: .topLeading) {
                ZStack {
                    Circle()
                        .stroke(conversation.isPinned ? Color.yellow : Color.blue, lineWidth: 2)
                        .frame(width: 52, height: 52)

                    if let avatarURL = conversation.avatarURL, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())
                            case .failure:
                                placeholderAvatar
                            case .empty:
                                ProgressView()
                                    .frame(width: 48, height: 48)
                            @unknown default:
                                placeholderAvatar
                            }
                        }
                    } else {
                        placeholderAvatar
                    }
                }

                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                        .offset(x: -4, y: -4)
                }
            }

            // Name, message preview, read receipt
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .fontWeight(conversation.isRead ? .regular : .bold)

                    if conversation.isArchived {
                        Text("Archived")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 4) {
                    if conversation.isRead {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Text(conversation.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Timestamp, unread badge, and overflow
            VStack(alignment: .trailing, spacing: 8) {
                Text(conversation.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.gray)

                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.blue)
                        .clipShape(Circle())
                }

                // Per-conversation overflow menu
                Menu {
                    Button {
                        onMarkRead()
                    } label: {
                        Label("Mark as read", systemImage: "checkmark.circle")
                    }
                    Button {
                        onPin()
                    } label: {
                        Label(
                            conversation.isPinned ? "Unpin" : "Pin",
                            systemImage: conversation.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    Button {
                        onArchive()
                    } label: {
                        Label(
                            conversation.isArchived ? "Unarchive" : "Archive",
                            systemImage: conversation.isArchived ? "tray.and.arrow.up" : "archivebox"
                        )
                    }
                    Divider()
                    Button(role: .destructive) {
                        // Block
                    } label: {
                        Label("Block", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 48, height: 48)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            )
    }
}

// MARK: - Preview

#Preview {
    BusinessInboxScreen()
        .preferredColorScheme(.dark)
}
