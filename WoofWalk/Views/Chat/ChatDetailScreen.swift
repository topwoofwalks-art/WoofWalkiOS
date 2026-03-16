import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatDetailScreen: View {
    let chatId: String
    @StateObject private var viewModel: ChatDetailViewModel
    @State private var messageText = ""
    @State private var selectedImage: UIImage?

    init(chatId: String) {
        self.chatId = chatId
        _viewModel = StateObject(wrappedValue: ChatDetailViewModel(chatId: chatId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let showDate = shouldShowDateSeparator(at: index)
                            let dateLabel = showDate ? dateLabelFor(message) : nil

                            ChatMessageRow(
                                message: message,
                                isFromCurrentUser: message.senderId == viewModel.currentUserId,
                                showDateSeparator: showDate,
                                dateLabel: dateLabel
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
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

                Button(action: {
                    guard !messageText.isEmpty else { return }
                    viewModel.sendMessage(messageText)
                    messageText = ""
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
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.messages[index].createdAt?.dateValue() ?? Date()
        let previous = viewModel.messages[index - 1].createdAt?.dateValue() ?? Date()
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

@MainActor
class ChatDetailViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var otherUserName = ""

    let chatId: String
    let currentUserId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(chatId: String) {
        self.chatId = chatId
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadMessages()
        loadChatInfo()
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
            .addSnapshotListener { [weak self] snapshot, error in
                if let error {
                    print("Messages error: \(error.localizedDescription)")
                    return
                }
                self?.messages = (snapshot?.documents ?? []).compactMap { try? $0.data(as: ChatMessage.self) }
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

    deinit { listener?.remove() }
}
