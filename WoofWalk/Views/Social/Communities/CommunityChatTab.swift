import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CommunityChatTab: View {
    let communityId: String
    @StateObject private var viewModel: CommunityChatViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    private let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    init(communityId: String) {
        self.communityId = communityId
        _viewModel = StateObject(wrappedValue: CommunityChatViewModel(communityId: communityId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(
                                message: message,
                                isOwn: message.senderId == viewModel.currentUserId,
                                brandColor: brandColor
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }

            // Input bar
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 0.5)

            HStack(spacing: 10) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .focused($isInputFocused)

                Button {
                    let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    messageText = ""
                    Task { await viewModel.sendMessage(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(.systemGray3) : brandColor
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .overlay {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView()
            } else if viewModel.messages.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Start the conversation!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Models

struct ChatMessage: Identifiable {
    let id: String
    let senderId: String
    let senderName: String
    let text: String
    let createdAt: Date
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage
    let isOwn: Bool
    let brandColor: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOwn { Spacer(minLength: 48) }

            if !isOwn {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 2) {
                if !isOwn {
                    Text(message.senderName)
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                }

                Text(message.text)
                    .font(.subheadline)
                    .foregroundColor(isOwn ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isOwn ? brandColor : Color(.systemGray5))
                    )

                Text(formatTime(message.createdAt))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            if !isOwn { Spacer(minLength: 48) }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - ViewModel

@MainActor
class CommunityChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    let currentUserId: String

    private let communityId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(communityId: String) {
        self.communityId = communityId
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadMessages()
    }

    func loadMessages() {
        isLoading = true
        listener = db.collection("communities").document(communityId)
            .collection("chat")
            .order(by: "createdAt")
            .limit(toLast: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    print("Chat error: \(error.localizedDescription)")
                    return
                }
                self.messages = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    return ChatMessage(
                        id: doc.documentID,
                        senderId: data["senderId"] as? String ?? "",
                        senderName: data["senderName"] as? String ?? "Unknown",
                        text: data["text"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }

    func sendMessage(_ text: String) async {
        guard !currentUserId.isEmpty else { return }
        let senderName = Auth.auth().currentUser?.displayName ?? "Unknown"
        let data: [String: Any] = [
            "senderId": currentUserId,
            "senderName": senderName,
            "text": text,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        do {
            try await db.collection("communities").document(communityId)
                .collection("chat").addDocument(data: data)
        } catch {
            print("Send message error: \(error.localizedDescription)")
        }
    }

    deinit { listener?.remove() }
}
