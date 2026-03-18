import SwiftUI

struct ShareWalkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let shareCard: WalkShareCard
    let walkId: String
    let onShare: (ShareDestination) -> Void

    /// Optional PB card to allow sharing PB as image
    var pbCard: PBShareCard? = nil

    @State private var showLiveShare = false
    @State private var showSavedToast = false
    @State private var showCopiedToast = false
    @State private var selectedTab: ShareCardTab = .walk

    enum ShareCardTab {
        case walk
        case personalBest
    }

    /// Pre-rendered share image at social-media resolution (1080x1350).
    /// Computed lazily on first access so the sheet opens fast.
    @MainActor private var renderedImage: UIImage? {
        switch selectedTab {
        case .walk:
            return ShareService.shared.renderCardToImage(shareCard, size: ShareCardSize.socialMedia)
        case .personalBest:
            guard let pbCard = pbCard else { return nil }
            return pbCard.renderToImage()
        }
    }

    /// Share text that accompanies the image
    private var shareText: String {
        switch selectedTab {
        case .walk:
            let dogLine = shareCard.dogNames.isEmpty ? "" : " with \(shareCard.dogNames.joined(separator: " & "))"
            let dist = FormatUtils.formatDistance(shareCard.distance)
            let dur = FormatUtils.formatDurationCompact(shareCard.duration)
            return "Just walked \(dist) in \(dur)\(dogLine)! \u{1F43E} #WoofWalk\nhttps://woofwalk.app"
        case .personalBest:
            guard let pbCard = pbCard else { return "" }
            return "New Personal Best with \(pbCard.dogName)! \u{1F3C6} #WoofWalk\nhttps://woofwalk.app"
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Tab picker if PB card is available
                if pbCard != nil {
                    Picker("Card Type", selection: $selectedTab) {
                        Text("Walk").tag(ShareCardTab.walk)
                        Text("Personal Best").tag(ShareCardTab.personalBest)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                // Preview of the share card (scaled down for display)
                Group {
                    switch selectedTab {
                    case .walk:
                        shareCard
                    case .personalBest:
                        if let pbCard = pbCard {
                            pbCard
                        }
                    }
                }
                .padding(.horizontal)
                .scaleEffect(0.85)

                // Share destinations
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(ShareDestination.allCases, id: \.self) { dest in
                            Button(action: {
                                handleShare(dest)
                            }) {
                                destinationButton(dest)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    toastView(text: "Saved to Photos", icon: "checkmark.circle.fill")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if showCopiedToast {
                    toastView(text: "Link Copied", icon: "doc.on.doc.fill")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showSavedToast)
            .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
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

    // MARK: - Share handling

    @MainActor private func handleShare(_ destination: ShareDestination) {
        if destination == .liveWalk {
            showLiveShare = true
            return
        }

        // Render the card to a full-resolution image
        guard let image = renderedImage else {
            // If rendering fails, notify caller and bail
            onShare(destination)
            return
        }

        switch destination {
        case .saveImage:
            ShareService.shared.saveToPhotos(image)
            showSavedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSavedToast = false
            }
        case .clipboard:
            ShareService.shared.copyToClipboard(shareText)
            showCopiedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showCopiedToast = false
            }
        default:
            ShareService.shared.shareToDestination(destination, image: image, text: shareText)
        }

        onShare(destination)
    }

    // MARK: - Sub-views

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

    private func toastView(text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
        .padding(.bottom, 24)
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
