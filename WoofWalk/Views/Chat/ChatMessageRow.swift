import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    let showDateSeparator: Bool
    let dateLabel: String?

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
                    }

                    // Timestamp
                    if let date = message.createdAt?.dateValue() {
                        Text(date, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if !isFromCurrentUser { Spacer(minLength: 60) }
            }
        }
    }
}
