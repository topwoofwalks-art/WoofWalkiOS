import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PhotosUI

struct ChatDetailScreen: View {
    let chatId: String
    @StateObject private var viewModel: ChatDetailViewModel
    @State private var messageText = ""
    @State private var selectedImage: UIImage?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var fullScreenImageUrl: String?

    init(chatId: String) {
        self.chatId = chatId
        _viewModel = StateObject(wrappedValue: ChatDetailViewModel(chatId: chatId))
    }

    private var filteredMessages: [ChatMessage] {
        guard isSearching, !searchText.isEmpty else { return viewModel.messages }
        return viewModel.messages.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search messages...", text: $searchText)
                        .textFieldStyle(.plain)
                    Button { isSearching = false; searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        // Pull-to-refresh sentinel
                        if viewModel.hasOlderMessages {
                            ProgressView()
                                .padding()
                                .onAppear { viewModel.loadOlderMessages() }
                        }

                        ForEach(Array(filteredMessages.enumerated()), id: \.offset) { index, message in
                            let showDate = shouldShowDateSeparator(at: index, in: filteredMessages)
                            let dateLabel = showDate ? dateLabelFor(message) : nil

                            ChatMessageRow(
                                message: message,
                                isFromCurrentUser: message.senderId == viewModel.currentUserId,
                                showDateSeparator: showDate,
                                dateLabel: dateLabel,
                                onImageTap: { url in
                                    fullScreenImageUrl = url
                                }
                            )
                            .id(message.id ?? "msg-\(index)")
                            .if(!searchText.isEmpty && message.text.localizedCaseInsensitiveContains(searchText)) { view in
                                view.overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.yellow, lineWidth: 2)
                                        .padding(.horizontal, -4)
                                )
                            }
                        }

                        // Typing indicator
                        if viewModel.isOtherUserTyping {
                            TypingIndicatorRow()
                                .id("typing-indicator")
                        }
                    }
                    .padding(.horizontal)
                }
                .refreshable {
                    await viewModel.loadOlderMessagesAsync()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.isOtherUserTyping) { isTyping in
                    if isTyping {
                        withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                PhotoMessagePicker(selectedImage: $selectedImage, onSend: { image in
                    viewModel.sendPhotoMessage(image)
                })

                TextField("Message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: messageText) { newValue in
                        viewModel.updateTypingStatus(!newValue.isEmpty)
                    }

                Button(action: {
                    guard !messageText.isEmpty else { return }
                    viewModel.sendMessage(messageText)
                    messageText = ""
                    viewModel.updateTypingStatus(false)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .secondary : .turquoise60)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .navigationTitle(viewModel.otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation { isSearching.toggle() }
                    if !isSearching { searchText = "" }
                } label: {
                    Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
            }
        }
        .fullScreenCover(item: $fullScreenImageUrl) { url in
            FullScreenImageViewer(imageUrl: url) {
                fullScreenImageUrl = nil
            }
        }
        .onDisappear {
            viewModel.updateTypingStatus(false)
        }
    }

    private func shouldShowDateSeparator(at index: Int, in messages: [ChatMessage]) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index].createdAt?.dateValue() ?? Date()
        let previous = messages[index - 1].createdAt?.dateValue() ?? Date()
        return !Calendar.current.isDate(current, inSameDayAs: previous)
    }

    private func dateLabelFor(_ message: ChatMessage) -> String? {
        guard let date = message.createdAt?.dateValue() else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorRow: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(dotOpacity(for: i))
                        .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.15), value: dotCount)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.neutral90)
            )
            Spacer(minLength: 60)
        }
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let phase = (dotCount + index) % 3
        switch phase {
        case 0: return 1.0
        case 1: return 0.6
        default: return 0.3
        }
    }
}

// MARK: - Full Screen Image Viewer

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct FullScreenImageViewer: View {
    let imageUrl: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    default:
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

// MARK: - Conditional Modifier

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - ViewModel

@MainActor
class ChatDetailViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var otherUserName = ""
    @Published var isOtherUserTyping = false
    @Published var hasOlderMessages = false

    let chatId: String
    let currentUserId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var typingListener: ListenerRegistration?
    private var oldestTimestamp: Timestamp?
    private let pageSize = 50

    init(chatId: String) {
        self.chatId = chatId
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadMessages()
        loadChatInfo()
        listenForTyping()
        markMessagesAsRead()
    }

    func loadChatInfo() {
        Task {
            do {
                let doc = try await db.collection("messageThreads").document(chatId).getDocument()
                if let chat = try? doc.data(as: Chat.self) {
                    otherUserName = chat.getOtherParticipantName(currentUserId: currentUserId) ?? "Chat"
                }
            } catch {
                print("Chat info error: \(error.localizedDescription)")
            }
        }
    }

    func loadMessages() {
        listener = db.collection("messageThreads").document(chatId).collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(toLast: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("Messages error: \(error.localizedDescription)")
                    return
                }
                let msgs = (snapshot?.documents ?? []).compactMap { try? $0.data(as: ChatMessage.self) }
                self.messages = msgs
                self.oldestTimestamp = msgs.first?.createdAt
                self.hasOlderMessages = msgs.count >= self.pageSize
                self.markMessagesAsRead()
            }
    }

    func loadOlderMessages() {
        guard let oldest = oldestTimestamp else { return }
        Task {
            do {
                let snapshot = try await db.collection("messageThreads").document(chatId).collection("messages")
                    .order(by: "createdAt", descending: true)
                    .start(after: [oldest])
                    .limit(to: pageSize)
                    .getDocuments()

                let olderMsgs = snapshot.documents.reversed().compactMap { try? $0.data(as: ChatMessage.self) }
                if olderMsgs.isEmpty {
                    hasOlderMessages = false
                } else {
                    messages.insert(contentsOf: olderMsgs, at: 0)
                    oldestTimestamp = messages.first?.createdAt
                    hasOlderMessages = olderMsgs.count >= pageSize
                }
            } catch {
                print("Load older messages error: \(error.localizedDescription)")
            }
        }
    }

    func loadOlderMessagesAsync() async {
        guard let oldest = oldestTimestamp else { return }
        do {
            let snapshot = try await db.collection("messageThreads").document(chatId).collection("messages")
                .order(by: "createdAt", descending: true)
                .start(after: [oldest])
                .limit(to: pageSize)
                .getDocuments()

            let olderMsgs = snapshot.documents.reversed().compactMap { try? $0.data(as: ChatMessage.self) }
            if olderMsgs.isEmpty {
                hasOlderMessages = false
            } else {
                messages.insert(contentsOf: olderMsgs, at: 0)
                oldestTimestamp = messages.first?.createdAt
                hasOlderMessages = olderMsgs.count >= pageSize
            }
        } catch {
            print("Load older messages error: \(error.localizedDescription)")
        }
    }

    func sendMessage(_ text: String) {
        let message = ChatMessage(
            chatId: chatId,
            senderId: currentUserId,
            senderName: "",
            text: text,
            readBy: [currentUserId],
            createdAt: Timestamp()
        )
        try? db.collection("messageThreads").document(chatId).collection("messages").addDocument(from: message)

        // Update last message on the thread
        Task {
            try? await db.collection("messageThreads").document(chatId).updateData([
                "lastMessage": text,
                "lastMessageSenderId": currentUserId,
                "lastMessageAt": FieldValue.serverTimestamp()
            ])
        }
    }

    func sendPhotoMessage(_ image: UIImage) {
        // TODO: Upload to Firebase Storage first, then send message with imageUrl
        print("Photo message sending not yet implemented")
    }

    // MARK: - Typing Indicator

    func updateTypingStatus(_ isTyping: Bool) {
        guard !currentUserId.isEmpty else { return }
        let ref = db.collection("messageThreads").document(chatId)
        Task {
            try? await ref.updateData([
                "typing.\(currentUserId)": isTyping ? FieldValue.serverTimestamp() : FieldValue.delete()
            ])
        }
    }

    private func listenForTyping() {
        typingListener = db.collection("messageThreads").document(chatId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let data = snapshot?.data() else { return }
                guard let typing = data["typing"] as? [String: Any] else {
                    self.isOtherUserTyping = false
                    return
                }
                // Check if any other user is currently typing (within last 10 seconds)
                let now = Date()
                let otherTyping = typing.contains { key, value in
                    guard key != self.currentUserId else { return false }
                    if let ts = value as? Timestamp {
                        return now.timeIntervalSince(ts.dateValue()) < 10
                    }
                    return false
                }
                self.isOtherUserTyping = otherTyping
            }
    }

    // MARK: - Read Receipts

    private func markMessagesAsRead() {
        guard !currentUserId.isEmpty else { return }
        for message in messages {
            guard let msgId = message.id,
                  message.senderId != currentUserId,
                  !message.readBy.contains(currentUserId) else { continue }
            Task {
                try? await db.collection("messageThreads").document(chatId)
                    .collection("messages").document(msgId)
                    .updateData(["readBy": FieldValue.arrayUnion([currentUserId])])
            }
        }
    }

    deinit {
        listener?.remove()
        typingListener?.remove()
    }
}
