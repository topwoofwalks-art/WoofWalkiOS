import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessInboxScreen: View {
    @StateObject private var viewModel = BusinessInboxViewModel()
    @State private var showQuickReply = false
    @State private var quickReplyChat: Chat?
    @State private var showAwaySettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Away mode banner
                if viewModel.isAwayMode {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.orange)
                        Text("Away mode is on")
                            .font(.subheadline.bold())
                        Spacer()
                        Button("Settings") { showAwaySettings = true }
                            .font(.subheadline)
                            .foregroundColor(.turquoise60)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                }

                List {
                    // Unread summary card
                    if viewModel.totalUnread > 0 {
                        Section {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.turquoise60.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "tray.full.fill")
                                        .font(.title3)
                                        .foregroundColor(.turquoise60)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(viewModel.totalUnread) unread message\(viewModel.totalUnread == 1 ? "" : "s")")
                                        .font(.headline)
                                    Text("Tap a conversation to respond")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Pinned conversations
                    if !viewModel.pinnedChats.isEmpty {
                        Section("Pinned") {
                            ForEach(viewModel.pinnedChats) { chat in
                                conversationRow(chat: chat)
                            }
                        }
                    }

                    // All conversations
                    Section(viewModel.pinnedChats.isEmpty ? "Conversations" : "Other") {
                        ForEach(viewModel.unpinnedChats) { chat in
                            conversationRow(chat: chat)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Business Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAwaySettings = true
                    } label: {
                        Image(systemName: viewModel.isAwayMode ? "moon.fill" : "moon")
                    }
                }
            }
            .navigationDestination(for: String.self) { chatId in
                ChatDetailScreen(chatId: chatId)
            }
            .sheet(isPresented: $showQuickReply) {
                if let chat = quickReplyChat {
                    QuickReplySheet(chatId: chat.id ?? "") { reply in
                        viewModel.sendQuickReply(chatId: chat.id ?? "", text: reply)
                        showQuickReply = false
                    }
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showAwaySettings) {
                NavigationStack {
                    AwayModeSettingsView(
                        isEnabled: $viewModel.isAwayMode,
                        autoReplyMessage: $viewModel.awayMessage,
                        startDate: $viewModel.awayStartDate,
                        endDate: $viewModel.awayEndDate,
                        onSave: { viewModel.saveAwaySettings() }
                    )
                }
                .presentationDetents([.large])
            }
            .overlay {
                if viewModel.chats.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Conversations")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Client messages will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func conversationRow(chat: Chat) -> some View {
        NavigationLink(value: chat.id ?? "") {
            HStack(spacing: 12) {
                // Avatar
                Circle().fill(Color.neutral90).frame(width: 44, height: 44)
                    .overlay {
                        if let photoUrl = chat.getOtherParticipantPhoto(currentUserId: viewModel.currentUserId),
                           let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill").foregroundColor(.secondary)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if viewModel.pinnedChatIds.contains(chat.id ?? "") {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Text(chat.getOtherParticipantName(currentUserId: viewModel.currentUserId) ?? "Unknown")
                            .font(.subheadline.bold())
                        Spacer()
                        if let date = chat.lastMessageAt?.dateValue() {
                            Text(FormatUtils.formatRelativeTime(date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text(chat.lastMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        let unread = chat.getUnreadCount(userId: viewModel.currentUserId)
                        if unread > 0 {
                            Text("\(unread)")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.turquoise60))
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                viewModel.archiveChat(chatId: chat.id ?? "")
            } label: {
                Label("Archive", systemImage: "archivebox.fill")
            }

            Button {
                viewModel.deleteChat(chatId: chat.id ?? "")
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                viewModel.togglePin(chatId: chat.id ?? "")
            } label: {
                let isPinned = viewModel.pinnedChatIds.contains(chat.id ?? "")
                Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button {
                quickReplyChat = chat
                showQuickReply = true
            } label: {
                Label("Quick Reply", systemImage: "bolt.fill")
            }
        }
        // Quick reply button overlay
        .overlay(alignment: .bottomTrailing) {
            Button {
                quickReplyChat = chat
                showQuickReply = true
            } label: {
                Image(systemName: "bolt.circle.fill")
                    .font(.title3)
                    .foregroundColor(.turquoise60)
            }
            .padding(.trailing, 4)
            .padding(.bottom, 4)
        }
    }
}

// MARK: - ViewModel

@MainActor
class BusinessInboxViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    @Published var isAwayMode = false
    @Published var awayMessage = "I'm currently unavailable. I'll reply as soon as possible."
    @Published var awayStartDate = Date()
    @Published var awayEndDate = Date().addingTimeInterval(86400)
    @Published var pinnedChatIds: Set<String> = []
    @Published var archivedChatIds: Set<String> = []

    let currentUserId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    var totalUnread: Int {
        chats.reduce(0) { $0 + $1.getUnreadCount(userId: currentUserId) }
    }

    var pinnedChats: [Chat] {
        chats.filter { pinnedChatIds.contains($0.id ?? "") && !archivedChatIds.contains($0.id ?? "") }
    }

    var unpinnedChats: [Chat] {
        chats.filter { !pinnedChatIds.contains($0.id ?? "") && !archivedChatIds.contains($0.id ?? "") }
    }

    init() {
        currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadChats()
        loadAwaySettings()
    }

    func loadChats() {
        guard !currentUserId.isEmpty else { return }
        isLoading = true
        listener = db.collection("messageThreads")
            .whereField("participantIds", arrayContains: currentUserId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Business inbox error: \(error.localizedDescription)")
                    return
                }
                self.chats = (snapshot?.documents ?? []).compactMap { try? $0.data(as: Chat.self) }
            }
    }

    func sendQuickReply(chatId: String, text: String) {
        guard !currentUserId.isEmpty else { return }
        let message = ChatMessage(
            chatId: chatId,
            senderId: currentUserId,
            senderName: "",
            text: text,
            readBy: [currentUserId],
            isAutoReply: true,
            createdAt: Timestamp()
        )
        try? db.collection("messageThreads").document(chatId).collection("messages").addDocument(from: message)

        Task {
            try? await db.collection("messageThreads").document(chatId).updateData([
                "lastMessage": text,
                "lastMessageSenderId": currentUserId,
                "lastMessageAt": FieldValue.serverTimestamp()
            ])
        }
    }

    func togglePin(chatId: String) {
        if pinnedChatIds.contains(chatId) {
            pinnedChatIds.remove(chatId)
        } else {
            pinnedChatIds.insert(chatId)
        }
        savePinnedChats()
    }

    func archiveChat(chatId: String) {
        archivedChatIds.insert(chatId)
    }

    func deleteChat(chatId: String) {
        Task {
            try? await db.collection("messageThreads").document(chatId).delete()
        }
    }

    func saveAwaySettings() {
        guard !currentUserId.isEmpty else { return }
        Task {
            try? await db.collection("businessProfiles").document(currentUserId).updateData([
                "awayMode.enabled": isAwayMode,
                "awayMode.message": awayMessage,
                "awayMode.startDate": Timestamp(date: awayStartDate),
                "awayMode.endDate": Timestamp(date: awayEndDate)
            ])
        }
    }

    func loadAwaySettings() {
        guard !currentUserId.isEmpty else { return }
        Task {
            if let doc = try? await db.collection("businessProfiles").document(currentUserId).getDocument(),
               let data = doc.data(),
               let away = data["awayMode"] as? [String: Any] {
                isAwayMode = away["enabled"] as? Bool ?? false
                awayMessage = away["message"] as? String ?? awayMessage
                if let start = away["startDate"] as? Timestamp { awayStartDate = start.dateValue() }
                if let end = away["endDate"] as? Timestamp { awayEndDate = end.dateValue() }
            }
        }
    }

    private func savePinnedChats() {
        guard !currentUserId.isEmpty else { return }
        Task {
            try? await db.collection("businessProfiles").document(currentUserId).updateData([
                "pinnedChats": Array(pinnedChatIds)
            ])
        }
    }

    deinit { listener?.remove() }
}
