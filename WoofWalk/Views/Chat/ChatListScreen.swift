import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatListScreen: View {
    @StateObject private var viewModel = ChatListViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.chats) { chat in
                NavigationLink(value: chat.id) {
                    ChatListRow(chat: chat, currentUserId: viewModel.currentUserId)
                }
            }
            .navigationTitle("Messages")
            .navigationDestination(for: String.self) { chatId in
                ChatDetailScreen(chatId: chatId)
            }
            .overlay {
                if viewModel.chats.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Messages")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Start a conversation")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct ChatListRow: View {
    let chat: Chat
    let currentUserId: String

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.neutral90).frame(width: 48, height: 48)
                .overlay {
                    if let photoUrl = chat.getOtherParticipantPhoto(currentUserId: currentUserId),
                       let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill").foregroundColor(.secondary)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.getOtherParticipantName(currentUserId: currentUserId) ?? "Unknown")
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
                    let unread = chat.getUnreadCount(userId: currentUserId)
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
}

@MainActor
class ChatListViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var isLoading = false

    let currentUserId: String
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadChats()
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
                    print("Chat list error: \(error.localizedDescription)")
                    return
                }
                self.chats = (snapshot?.documents ?? []).compactMap { doc in
                    try? doc.data(as: Chat.self)
                }
            }
    }

    deinit { listener?.remove() }
}
