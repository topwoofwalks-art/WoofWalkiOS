import UIKit
import SwiftUI
import FirebaseFirestore

// MARK: - View → UIImage rendering

extension View {
    /// Renders this SwiftUI view to a UIImage at the given point size.
    /// Uses UIHostingController + UIGraphicsImageRenderer for crisp output.
    func renderToImage(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self.ignoresSafeArea())
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .white

        // Force layout so all subviews are measured before snapshotting
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

// MARK: - Share card dimensions

enum ShareCardSize {
    /// 4:5 ratio matching Android (1080x1350) — ideal for social media
    static let socialMedia = CGSize(width: 1080, height: 1350)

    /// Smaller preview size for in-app display
    static let preview = CGSize(width: 360, height: 450)
}

// MARK: - ShareService

@MainActor
class ShareService {
    static let shared = ShareService()

    private let db = Firestore.firestore()

    // MARK: - Card rendering

    /// Renders a SwiftUI share card view to a social-media-ready UIImage (1080x1350, 4:5).
    func renderCardToImage<V: View>(_ view: V, size: CGSize = ShareCardSize.socialMedia) -> UIImage? {
        let image = view.renderToImage(size: size)
        // Sanity check: if the image is entirely transparent something went wrong
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        return image
    }

    // MARK: - System share sheet

    func shareImage(_ image: UIImage, text: String? = nil) {
        var items: [Any] = [image]
        if let text = text { items.append(text) }

        presentActivityViewController(items: items)
    }

    // MARK: - Destination routing

    func shareToDestination(_ destination: ShareDestination, image: UIImage, text: String) {
        switch destination {
        case .clipboard:
            copyToClipboard(text)
        case .saveImage:
            saveToPhotos(image)
        case .instagramStory:
            shareToInstagramStory(image: image)
        case .instagram:
            shareToInstagram(image: image)
        case .whatsapp:
            shareToWhatsApp(image: image, text: text)
        case .facebook:
            shareToFacebook(image: image, text: text)
        case .twitter:
            shareToTwitter(image: image, text: text)
        case .messages:
            shareToMessages(image: image, text: text)
        case .nextdoor:
            // Nextdoor has no public URL scheme; fall through to system share
            shareImage(image, text: text)
        case .feed:
            // In-app feed posting is handled elsewhere; fall through to system share
            shareImage(image, text: text)
        case .liveWalk:
            // Handled by ShareWalkSheet directly (presents LiveShareView)
            break
        case .more:
            shareImage(image, text: text)
        }
    }

    // MARK: - Clipboard

    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    // MARK: - Save to Photos

    func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    // MARK: - Instagram Stories

    func shareToInstagramStory(image: UIImage) {
        guard canOpenApp("instagram-stories") else {
            shareImage(image)
            return
        }

        guard let adapted = InstagramStoryAdapter.adapt(cardImage: image),
              let imageData = adapted.pngData() else {
            shareImage(image)
            return
        }

        let pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.backgroundImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#0A1628",
            "com.instagram.sharedSticker.backgroundBottomColor": "#1B2838",
        ]]

        let options: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5),
        ]

        UIPasteboard.general.setItems(pasteboardItems, options: options)

        if let url = URL(string: "instagram-stories://share?source_application=com.woofwalk.app") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Instagram (Feed/DM)

    func shareToInstagram(image: UIImage) {
        // Instagram doesn't expose a direct feed-post URL scheme.
        // Best approach: save image to camera roll then open Instagram so user can post.
        saveToPhotos(image)

        if canOpenApp("instagram") {
            if let url = URL(string: "instagram://app") {
                UIApplication.shared.open(url)
            }
        } else {
            shareImage(image)
        }
    }

    // MARK: - WhatsApp

    func shareToWhatsApp(image: UIImage, text: String) {
        guard canOpenApp("whatsapp") else {
            shareImage(image, text: text)
            return
        }

        // Place image on pasteboard so it's available when WhatsApp opens
        UIPasteboard.general.image = image

        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "whatsapp://send?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Facebook

    func shareToFacebook(image: UIImage, text: String) {
        // Try Facebook app scheme first, fall back to system share
        if canOpenApp("fb") {
            // Facebook doesn't allow pre-filling text via URL scheme (platform policy),
            // so we put the image on pasteboard and open the composer
            UIPasteboard.general.image = image
            if let url = URL(string: "fb://publish/profile/me") {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback: system share sheet which includes Facebook if installed
        shareImage(image, text: text)
    }

    // MARK: - Twitter / X

    func shareToTwitter(image: UIImage, text: String) {
        // Try X (Twitter) app scheme
        if canOpenApp("twitter") {
            UIPasteboard.general.image = image
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "twitter://post?message=\(encoded)") {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback: system share
        shareImage(image, text: text)
    }

    // MARK: - Messages (iMessage / SMS)

    func shareToMessages(image: UIImage, text: String) {
        // Use system share sheet filtered to Messages if possible,
        // but UIActivityViewController doesn't support direct filtering well.
        // Best UX: open system share with image + text — Messages is always first option.
        shareImage(image, text: text)
    }

    // MARK: - App availability

    func canOpenApp(_ scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - Present UIActivityViewController

    private func presentActivityViewController(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Handle iPad popover
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0, height: 0
                )
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Live share link

    func generateLiveShareLink(walkId: String) async -> String {
        let linkId = generateShortId()
        let docData: [String: Any] = [
            "walkId": walkId,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(4 * 60 * 60)),
            "active": true,
        ]

        do {
            try await db.collection("liveShares").document(linkId).setData(docData)
        } catch {
            print("Failed to create live share: \(error.localizedDescription)")
        }

        return "https://woofwalk.app/live/\(linkId)"
    }

    private func generateShortId() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
