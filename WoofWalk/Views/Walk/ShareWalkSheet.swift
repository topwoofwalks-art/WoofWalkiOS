import SwiftUI

struct ShareWalkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shareCard: WalkShareCard
    let walkId: String
    let onShare: (ShareDestination) -> Void

    @State private var showLiveShare = false

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
                            Button(action: {
                                if dest == .liveWalk {
                                    showLiveShare = true
                                } else {
                                    onShare(dest)
                                }
                            }) {
                                destinationButton(dest)
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
            .sheet(isPresented: $showLiveShare) {
                LiveShareView(walkId: walkId, onStopSharing: {})
            }
        }
    }

    private func destinationButton(_ dest: ShareDestination) -> some View {
        VStack(spacing: 6) {
            Image(systemName: dest.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(dest.color))
            Text(dest.displayName)
                .font(.caption2)
                .foregroundColor(.primary)
        }
    }
}

enum ShareDestination: String, CaseIterable {
    case feed = "FEED"
    case instagramStory = "INSTAGRAM_STORY"
    case instagram = "INSTAGRAM"
    case facebook = "FACEBOOK"
    case twitter = "TWITTER"
    case whatsapp = "WHATSAPP"
    case nextdoor = "NEXTDOOR"
    case messages = "MESSAGES"
    case liveWalk = "LIVE_WALK"
    case clipboard = "CLIPBOARD"
    case saveImage = "SAVE_IMAGE"
    case more = "MORE"

    var displayName: String {
        switch self {
        case .feed: return "Feed"
        case .instagramStory: return "IG Story"
        case .instagram: return "Instagram"
        case .facebook: return "Facebook"
        case .twitter: return "X"
        case .whatsapp: return "WhatsApp"
        case .nextdoor: return "Nextdoor"
        case .messages: return "Messages"
        case .liveWalk: return "Live Walk"
        case .clipboard: return "Copy Link"
        case .saveImage: return "Save"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .feed: return "newspaper"
        case .instagramStory: return "camera.filters"
        case .instagram: return "camera.circle"
        case .facebook: return "person.2.circle"
        case .twitter: return "at.circle"
        case .whatsapp: return "message.circle"
        case .nextdoor: return "house.circle"
        case .messages: return "bubble.left.circle"
        case .liveWalk: return "location.circle.fill"
        case .clipboard: return "doc.on.doc.fill"
        case .saveImage: return "square.and.arrow.down"
        case .more: return "ellipsis.circle"
        }
    }

    var color: Color {
        switch self {
        case .feed: return .turquoise60
        case .instagramStory: return Color(red: 225/255, green: 48/255, blue: 108/255)
        case .instagram: return .purple
        case .facebook: return .blue
        case .twitter: return .black
        case .whatsapp: return .green
        case .nextdoor: return Color(red: 0, green: 166/255, blue: 82/255)
        case .messages: return .blue
        case .liveWalk: return .turquoise60
        case .clipboard: return .gray
        case .saveImage: return .turquoise60
        case .more: return .gray
        }
    }
}
