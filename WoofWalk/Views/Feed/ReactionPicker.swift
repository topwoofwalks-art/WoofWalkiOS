import SwiftUI

enum ReactionType: String, CaseIterable {
    case kudos, love, fire, paw, impressive, funny

    var emoji: String {
        switch self {
        case .kudos: return "\u{1F44F}"
        case .love: return "\u{2764}\u{FE0F}"
        case .fire: return "\u{1F525}"
        case .paw: return "\u{1F43E}"
        case .impressive: return "\u{1F4AA}"
        case .funny: return "\u{1F602}"
        }
    }

    /// Firestore key matches Android format
    var firestoreKey: String { rawValue.uppercased() }
}

struct ReactionPicker: View {
    let onReaction: (ReactionType) -> Void
    @Binding var isPresented: Bool
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(ReactionType.allCases.enumerated()), id: \.element) { index, reaction in
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onReaction(reaction)
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPresented = false
                    }
                } label: {
                    Text(reaction.emoji)
                        .font(.title)
                        .scaleEffect(appeared ? 1.0 : 0.01)
                        .opacity(appeared ? 1.0 : 0.0)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.6)
                                .delay(Double(index) * 0.05),
                            value: appeared
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .scaleEffect(appeared ? 1.0 : 0.8)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appeared)
        .onAppear { appeared = true }
    }
}

struct ReactionSummary: View {
    let reactions: [String: Int]

    /// Top 3 reaction types by count, with total
    var body: some View {
        let sorted = reactions
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
        let total = sorted.reduce(0) { $0 + $1.value }

        if total > 0 {
            HStack(spacing: 4) {
                // Show top 3 emojis
                ForEach(sorted.prefix(3), id: \.key) { key, _ in
                    if let type = ReactionType(rawValue: key.lowercased()) {
                        Text(type.emoji).font(.caption)
                    }
                }
                Text("\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
