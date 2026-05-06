import SwiftUI

/// Group chat tab. Bubbles with day-separator headers, scroll-pin (only
/// auto-scroll when the user is near the bottom), and Result-based send
/// with snackbar retry — matches Android's audit-fix UX from `ec9cbc2`.
struct CommunityChatTab: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    @State private var messageText: String = ""
    @State private var isSending: Bool = false
    @State private var sendError: String?
    @State private var lastFailedMessage: String?
    @State private var nearBottom: Bool = true
    @State private var lastMessageId: String?

    private static let brandColor = Color(red: 0/255, green: 160/255, blue: 176/255)

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(groupedByDay, id: \.0) { day, msgs in
                            daySeparator(day)
                            ForEach(msgs) { msg in
                                bubble(for: msg)
                                    .id(msg.id ?? UUID().uuidString)
                            }
                        }
                        // Sentinel for nearBottom detection — when this id is
                        // visible, we're at/near the latest message.
                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                            .onAppear { nearBottom = true }
                            .onDisappear { nearBottom = false }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.chatMessages.last?.id) { newId in
                    // Auto-scroll only when the user is near the bottom — if
                    // they're scrolled up reading old messages, don't yank.
                    guard let newId = newId, newId != lastMessageId, nearBottom else {
                        lastMessageId = newId
                        return
                    }
                    lastMessageId = newId
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
                .onAppear {
                    // Initial scroll to bottom on tab open.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
            }

            if let err = sendError {
                snackbar(err)
            }

            inputBar
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Grouping

    private var groupedByDay: [(Date, [CommunityChatMessage])] {
        let calendar = Calendar.current
        let messages = viewModel.chatMessages
        let groups = Dictionary(grouping: messages) {
            calendar.startOfDay(for: $0.date)
        }
        return groups.keys.sorted().map { ($0, groups[$0]!.sorted { $0.createdAt < $1.createdAt }) }
    }

    private func daySeparator(_ day: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let now = Date()
        let calendar = Calendar.current
        let label: String
        if calendar.isDate(day, inSameDayAs: now) {
            label = "Today"
        } else if calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            label = "Yesterday"
        } else {
            label = formatter.string(from: day)
        }
        return HStack {
            Spacer()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Bubble

    @ViewBuilder
    private func bubble(for msg: CommunityChatMessage) -> some View {
        let isMine = msg.authorId == viewModel.currentUserId
        HStack(alignment: .top, spacing: 8) {
            if !isMine {
                authorAvatar(for: msg)
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if !isMine {
                    Text(msg.authorName.isEmpty ? "Unknown" : msg.authorName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(msg.content)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMine ? Self.brandColor : Color.secondary.opacity(0.15))
                    .foregroundColor(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(timeStr(msg.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if isMine {
                Spacer()
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    @ViewBuilder
    private func authorAvatar(for msg: CommunityChatMessage) -> some View {
        if let urlStr = msg.authorPhotoUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundColor(.secondary.opacity(0.4))
        }
    }

    private func timeStr(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Snackbar (retry on send failure)

    private func snackbar(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            if let last = lastFailedMessage {
                Button("Retry") {
                    Task {
                        await sendMessage(retryText: last)
                    }
                }
                .font(.caption.bold())
                .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.85))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(canSend ? Self.brandColor : .secondary.opacity(0.4))
                    .font(.system(size: 22))
            }
            .disabled(!canSend || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 0.5)
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Send a message. On success the input is cleared; on failure a
    /// snackbar lets the user retry without losing their text. Mirrors
    /// Android's CommunityChatTab Result-based pattern.
    private func sendMessage(retryText: String? = nil) async {
        let text = retryText ?? messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        sendError = nil
        do {
            _ = try await viewModel.sendChatMessage(text)
            if retryText == nil {
                messageText = ""
            }
            lastFailedMessage = nil
        } catch {
            sendError = "Failed to send: \(error.localizedDescription)"
            lastFailedMessage = text
            if retryText == nil {
                // Keep the text in the input on first failure so the user
                // can edit + retry. The retry button uses the cached copy.
            }
        }
        isSending = false
    }
}
