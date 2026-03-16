import SwiftUI

struct ShareWalkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shareCard: WalkShareCard
    let onShare: (ShareDestination) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Preview
                shareCard
                    .padding(.horizontal)
                    .scaleEffect(0.85)

                // Share destinations
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(ShareDestination.allCases, id: \.self) { dest in
                            Button(action: { onShare(dest) }) {
                                VStack(spacing: 6) {
                                    Image(systemName: dest.icon)
                                        .font(.title2)
                                        .foregroundColor(dest.color)
                                        .frame(width: 56, height: 56)
                                        .background(Circle().fill(dest.color.opacity(0.1)))
                                    Text(dest.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Share Walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

enum ShareDestination: String, CaseIterable {
    case feed = "FEED"
    case instagram = "INSTAGRAM"
    case facebook = "FACEBOOK"
    case twitter = "TWITTER"
    case whatsapp = "WHATSAPP"
    case messages = "MESSAGES"
    case clipboard = "CLIPBOARD"
    case saveImage = "SAVE_IMAGE"
    case more = "MORE"

    var displayName: String {
        switch self {
        case .feed: return "Feed"
        case .instagram: return "Instagram"
        case .facebook: return "Facebook"
        case .twitter: return "X"
        case .whatsapp: return "WhatsApp"
        case .messages: return "Messages"
        case .clipboard: return "Copy Link"
        case .saveImage: return "Save"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .feed: return "newspaper"
        case .instagram: return "camera.circle"
        case .facebook: return "person.2.circle"
        case .twitter: return "at.circle"
        case .whatsapp: return "message.circle"
        case .messages: return "bubble.left.circle"
        case .clipboard: return "doc.on.doc.fill"
        case .saveImage: return "square.and.arrow.down"
        case .more: return "ellipsis.circle"
        }
    }

    var color: Color {
        switch self {
        case .feed: return .turquoise60
        case .instagram: return .purple
        case .facebook: return .blue
        case .twitter: return .black
        case .whatsapp: return .green
        case .messages: return .blue
        case .clipboard: return .gray
        case .saveImage: return .turquoise60
        case .more: return .gray
        }
    }
}
