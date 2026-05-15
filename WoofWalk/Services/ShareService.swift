import UIKit
import SwiftUI
import FirebaseAuth
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

    /// Multi-image system share — used when the user has selected walk
    /// photos in addition to the share card. UIActivityViewController
    /// accepts a heterogeneous items array; the picked destination decides
    /// what it can handle (Messages takes them all, Twitter clips to 4,
    /// etc.).
    func shareImages(_ images: [UIImage], text: String? = nil) {
        var items: [Any] = images
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

        // Put image on pasteboard as JPEG — WhatsApp reads public.jpeg from the
        // clipboard rather than the raw UIImage object.
        if let jpegData = image.jpegData(compressionQuality: 0.9) {
            UIPasteboard.general.setData(jpegData, forPasteboardType: "public.jpeg")
        } else {
            UIPasteboard.general.image = image
        }

        // URLComponents handles query encoding per RFC 3986 (newlines, emoji, &, +).
        var components = URLComponents(string: "whatsapp://send")
        components?.queryItems = [URLQueryItem(name: "text", value: text)]
        guard let url = components?.url else {
            shareImage(image, text: text)
            return
        }
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            if !success {
                print("[ShareService] WhatsApp open failed, falling back to system share")
                self?.shareImage(image, text: text)
            }
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
            var components = URLComponents(string: "twitter://post")
            components?.queryItems = [URLQueryItem(name: "message", value: text)]
            if let url = components?.url {
                UIApplication.shared.open(url, options: [:]) { [weak self] success in
                    if !success {
                        self?.shareImage(image, text: text)
                    }
                }
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

    /// Result of creating a live share — the recipient-facing URL plus the
    /// Firestore doc id so the caller (WalkTrackingService) can push
    /// location updates onto it for the duration of the walk.
    struct LiveShareHandle {
        let linkId: String
        let url: String
    }

    /// Create a `live_share_links` doc in the shape Android writes. The
    /// recipient page (https://woofwalk.app/live/{token}) is shared by
    /// Android, iOS, and the portal so the schema MUST match Android
    /// (`LiveShareRepository.kt`) — same collection name, same field
    /// names, same types. Differing here means the portal renders a
    /// blank page when the walker is on iOS.
    func generateLiveShareLink(
        walkId: String,
        walkerFirstName: String = "",
        dogNames: [String] = []
    ) async -> LiveShareHandle? {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("[ShareService] Cannot create live share: no signed-in user")
            return nil
        }

        let linkId = UUID().uuidString
        let token = UUID().uuidString
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let expiresAtMs = nowMs + 4 * 3600 * 1000  // 4 hours

        // Schema mirrors Android `LiveShareRepository.createShareLink` —
        // `sessionId`/`userId`/`token`/`createdAt`/`expiresAt`/`isActive`/
        // `walkerFirstName`/`dogNames`/`lastLat`/`lastLng`/`lastUpdatedAt`/
        // `distanceMeters`/`durationSec`/`routePoints`/`walkEnded`.
        let docData: [String: Any] = [
            "id": linkId,
            "sessionId": walkId,
            "userId": uid,
            "token": token,
            "createdAt": nowMs,
            "expiresAt": expiresAtMs,
            "isActive": true,
            "walkerFirstName": walkerFirstName,
            "dogNames": dogNames,
            "lastLat": 0.0,
            "lastLng": 0.0,
            "lastUpdatedAt": 0,
            "distanceMeters": 0.0,
            "durationSec": 0,
            "routePoints": [[String: Double]](),
            "walkEnded": false,
        ]

        do {
            try await db.collection("live_share_links").document(linkId).setData(docData)
        } catch {
            print("[ShareService] Failed to create live share: \(error.localizedDescription)")
            return nil
        }

        return LiveShareHandle(
            linkId: linkId,
            url: "https://woofwalk.app/live/\(token)"
        )
    }

    /// Push the latest GPS fix + walk stats onto an active live share.
    /// Called periodically from `WalkTrackingService` for the duration
    /// of the share. Route points are trimmed to the last 500 entries
    /// to keep the doc under Firestore's 1 MiB ceiling — mirrors
    /// Android `LiveShareRepository.updateLiveLocation`.
    func updateLiveShareLocation(
        linkId: String,
        lat: Double,
        lng: Double,
        distanceMeters: Double,
        durationSec: Int64,
        routePoints: [[String: Double]]
    ) async {
        let trimmedPoints: [[String: Double]] = routePoints.count > 500
            ? Array(routePoints.suffix(500))
            : routePoints

        do {
            try await db.collection("live_share_links").document(linkId).updateData([
                "lastLat": lat,
                "lastLng": lng,
                "lastUpdatedAt": Int64(Date().timeIntervalSince1970 * 1000),
                "distanceMeters": distanceMeters,
                "durationSec": durationSec,
                "routePoints": trimmedPoints,
            ])
        } catch {
            print("[ShareService] Failed to update live share location: \(error.localizedDescription)")
        }
    }

    /// Mark the underlying walk as ended on a live share. Bumps
    /// `expiresAt` to 7 days from now so the recap page stays reachable
    /// after the live portion is over — recipient page's rules gate on
    /// `expiresAt` alone, so the doc has to remain within its expiry
    /// window for the "Walk Complete!" recap UI to render. Mirrors
    /// Android `LiveShareRepository.markWalkEnded`.
    func markLiveShareWalkEnded(linkId: String) async {
        let recapExpiresAtMs = Int64(Date().timeIntervalSince1970 * 1000) + 7 * 24 * 3600 * 1000
        do {
            try await db.collection("live_share_links").document(linkId).updateData([
                "walkEnded": true,
                "isActive": false,
                "expiresAt": recapExpiresAtMs,
            ])
        } catch {
            print("[ShareService] Failed to mark live share walk ended: \(error.localizedDescription)")
        }
    }

    /// Deactivate a live share without finalising it as a recap. Used
    /// when the walker manually taps "Stop Sharing" before the walk
    /// ends. Mirrors Android `LiveShareRepository.deactivateLink`.
    func deactivateLiveShare(linkId: String) async {
        do {
            try await db.collection("live_share_links").document(linkId).updateData([
                "isActive": false,
            ])
        } catch {
            print("[ShareService] Failed to deactivate live share: \(error.localizedDescription)")
        }
    }
}
