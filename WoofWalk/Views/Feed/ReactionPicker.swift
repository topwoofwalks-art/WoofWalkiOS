import SwiftUI

enum ReactionType: String, CaseIterable {
    case kudos = "KUDOS"
    case love = "LOVE"
    case funny = "FUNNY"
    case wow = "WOW"

    var emoji: String {
        switch self {
        case .kudos: return "\u{1F44F}"
        case .love: return "\u{2764}\u{FE0F}"
        case .funny: return "\u{1F602}"
        case .wow: return "\u{1F929}"
        }
    }
}

struct ReactionPicker: View {
    let onReaction: (ReactionType) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ReactionType.allCases, id: \.self) { reaction in
                Button(action: {
                    onReaction(reaction)
                    isPresented = false
                }) {
                    Text(reaction.emoji)
                        .font(.title)
                        .scaleEffect(1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.regularMaterial).shadow(radius: 4))
    }
}
