import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Conversation Preview Model

struct ConversationPreview: Identifiable {
    let id: String
    let name: String
    let lastMessage: String
    let timestamp: Date
    let avatarURL: String?
    let isFromCurrentUser: Bool
    let unreadCount: Int
}

// MARK: - Client Messages Screen

struct ClientMessagesScreen: View {
    @StateObject private var viewModel = ClientMessagesViewModel()

    var body: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                NavigationLink(value: conversation.id) {
                    ClientMessageRow(conversation: conversation)
                }
                .listRowBackground(Color(.systemBackground))
            }
        }
        .listStyle(.plain)
        .navigationTitle("Messages")
        .navigationDestination(for: String.self) { chatId in
            ChatDetailScreen(chatId: chatId)
        }
        .overlay {
            if viewModel.conversations.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Messages")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Your conversations will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

// MARK: - Message Row

private struct ClientMessageRow: View {
    let conversation: ConversationPreview

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView

            // Name + last message
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(messagePreview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.turquoise60))
                    }
                }
            }

            // Overflow menu
            Menu {
                Button(role: .destructive) {
                    // Delete action
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    // Mute action
                } label: {
                    Label("Mute", systemImage: "bell.slash")
                }
                Button {
                    // Archive action
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 4)
    }

    private var messagePreview: String {
        if conversation.isFromCurrentUser {
            return "You: \(conversation.lastMessage)"
        }
        return conversation.lastMessage
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(conversation.timestamp) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(conversation.timestamp) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "dd/MM/yy"
        }
        return formatter.string(from: conversation.timestamp)
    }

    @ViewBuilder
    private var avatarView: some View {
        Circle()
            .fill(Color.neutral90)
            .frame(width: 50, height: 50)
            .overlay {
                if let urlString = conversation.avatarURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                }
            }
            .clipShape(Circle())
    }
}

// MARK: - View Model

@MainActor
class ClientMessagesViewModel: ObservableObject {
    @Published var conversations: [ConversationPreview] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let currentUserId: String

    init() {
        currentUserId = Auth.auth().currentUser?.uid ?? ""
        loadConversations()
    }

    func loadConversations() {
        guard !currentUserId.isEmpty else { return }
        isLoading = true

        listener = db.collection("messageThreads")
            .whereField("participantIds", arrayContains: currentUserId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    print("ClientMessages error: \(error.localizedDescription)")
                    return
                }

                self.conversations = (snapshot?.documents ?? []).compactMap { doc in
                    self.mapToConversation(doc: doc)
                }
            }
    }

    private func mapToConversation(doc: QueryDocumentSnapshot) -> ConversationPreview? {
        let data = doc.data()
        let participantNames = data["participantNames"] as? [String: String] ?? [:]
        let participantPhotos = data["participantPhotos"] as? [String: String] ?? [:]
        let lastMessage = data["lastMessage"] as? String ?? ""
        let lastSenderId = data["lastSenderId"] as? String ?? ""
        let timestamp = (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date()

        // Find the other participant's info
        let otherName = participantNames.first(where: { $0.key != currentUserId })?.value ?? "Unknown"
        let otherPhoto = participantPhotos.first(where: { $0.key != currentUserId })?.value

        // Unread count
        let unreadCounts = data["unreadCounts"] as? [String: Int] ?? [:]
        let unread = unreadCounts[currentUserId] ?? 0

        return ConversationPreview(
            id: doc.documentID,
            name: otherName,
            lastMessage: lastMessage,
            timestamp: timestamp,
            avatarURL: otherPhoto,
            isFromCurrentUser: lastSenderId == currentUserId,
            unreadCount: unread
        )
    }

    deinit { listener?.remove() }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ClientMessagesScreen()
    }
    .preferredColorScheme(.dark)
}
