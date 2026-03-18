import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let showDateSeparator: Bool
    let dateLabel: String?
    var currentUserId: String = ""
    var onImageTap: ((String) -> Void)? = nil
    var onReactionTap: ((String, String) -> Void)? = nil // (messageId, emoji)

    @State private var showReactionPicker = false

    var body: some View {
        VStack(spacing: 8) {
            if showDateSeparator, let label = dateLabel {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.neutral90))
                    .padding(.vertical, 8)
            }

            // Reaction picker overlay
            if showReactionPicker {
                HStack {
                    if isFromCurrentUser { Spacer() }
                    MessageReactionPicker(
                        onReactionSelected: { emoji in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                showReactionPicker = false
                            }
                            if let msgId = message.id {
                                onReactionTap?(msgId, emoji)
                            }
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                showReactionPicker = false
                            }
                        }
                    )
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    if !isFromCurrentUser { Spacer() }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                if isFromCurrentUser { Spacer(minLength: 60) }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    if !isFromCurrentUser {
                        Text(message.senderName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Photo message
                    if let imageUrl = message.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                                    .frame(maxWidth: 220, maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        onImageTap?(imageUrl)
                                    }
                            case .failure:
                                Image(systemName: "photo")
                                    .frame(width: 100, height: 100)
                                    .background(Color.neutral90)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            default:
                                ProgressView()
                                    .frame(width: 100, height: 100)
                            }
                        }
                        .onLongPressGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                showReactionPicker.toggle()
                            }
                        }
                    }

                    // Text message
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isFromCurrentUser ? Color.turquoise60 : Color.neutral90)
                            )
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                            .onLongPressGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                    showReactionPicker.toggle()
                                }
                            }
                    }

                    // Reaction summary
                    if !message.reactions.isEmpty {
                        MessageReactionSummary(
                            reactions: message.reactions,
                            currentUserId: currentUserId,
                            onReactionTap: { emoji in
                                if let msgId = message.id {
                                    onReactionTap?(msgId, emoji)
                                }
                            }
                        )
                    }

                    // Timestamp + read receipt
                    HStack(spacing: 4) {
                        if let date = message.createdAt?.dateValue() {
                            Text(formatMessageTime(date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // Read receipt indicators (only for sent messages)
                        if isFromCurrentUser {
                            readReceiptIndicator
                        }
                    }
                }

                if !isFromCurrentUser { Spacer(minLength: 60) }
            }
        }
    }

    // MARK: - Read Receipt Indicator

    @ViewBuilder
    private var readReceiptIndicator: some View {
        let isRead = message.readBy.count > 1 // more than just the sender

        if isRead {
            // Double checkmark blue = read
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.blue)
        } else {
            // Single checkmark gray = sent
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Time Formatting

    private func formatMessageTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            // Today: "HH:mm"
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }

        // Check if within this week (last 7 days)
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date > weekAgo {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE HH:mm"
            return formatter.string(from: date)
        }

        // Older: "d MMM"
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
