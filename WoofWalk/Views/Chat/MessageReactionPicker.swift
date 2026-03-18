import SwiftUI

struct MessageReactionPicker: View {
    let onReactionSelected: (String) -> Void
    let onDismiss: () -> Void

    static let availableReactions = [
        "\u{1F44D}", "\u{2764}\u{FE0F}", "\u{1F602}", "\u{1F62E}", "\u{1F622}", "\u{1F525}", "\u{1F44F}", "\u{1F43E}"
    ]

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(Self.availableReactions.enumerated()), id: \.offset) { index, emoji in
                Text(emoji)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(.systemGray5)))
                    .scaleEffect(appeared ? 1.0 : 0.01)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.6)
                            .delay(Double(index) * 0.04),
                        value: appeared
                    )
                    .onTapGesture {
                        onReactionSelected(emoji)
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .onAppear { appeared = true }
    }
}

// MARK: - Reaction Summary

struct MessageReactionSummary: View {
    let reactions: [String: [String]]
    let currentUserId: String
    let onReactionTap: (String) -> Void

    var body: some View {
        let sorted = reactions
            .filter { !$0.value.isEmpty }
            .sorted { $0.value.count > $1.value.count }

        if !sorted.isEmpty {
            HStack(spacing: 4) {
                ForEach(sorted, id: \.key) { emoji, userIds in
                    let isSelected = userIds.contains(currentUserId)

                    Button {
                        onReactionTap(emoji)
                    } label: {
                        HStack(spacing: 2) {
                            Text(emoji)
                                .font(.caption)
                            if userIds.count > 1 {
                                Text("\(userIds.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.turquoise60.opacity(0.2) : Color(.systemGray5))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isSelected ? Color.turquoise60 : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}
