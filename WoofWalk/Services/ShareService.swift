import UIKit
import SwiftUI
import FirebaseFirestore

@MainActor
class ShareService {
    static let shared = ShareService()

    private let db = Firestore.firestore()

    func shareImage(_ image: UIImage, text: String? = nil) {
        var items: [Any] = [image]
        if let text = text { items.append(text) }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    func renderCardToImage<V: View>(_ view: V, size: CGSize = CGSize(width: 400, height: 500)) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    func shareToDestination(_ destination: ShareDestination, image: UIImage, text: String) {
        switch destination {
        case .clipboard:
            copyToClipboard(text)
        case .saveImage:
            saveToPhotos(image)
        case .instagramStory:
            shareToInstagramStory(image: image)
        case .whatsapp:
            shareToWhatsApp(image: image, text: text)
        default:
            shareImage(image, text: text)
        }
    }

    // MARK: - Instagram Stories

    func shareToInstagramStory(image: UIImage) {
        guard canOpenApp("instagram-stories") else {
            // Fall back to regular share sheet
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

    // MARK: - WhatsApp

    func shareToWhatsApp(image: UIImage, text: String) {
        guard canOpenApp("whatsapp") else {
            shareImage(image, text: text)
            return
        }

        // WhatsApp doesn't support direct image passing via URL scheme;
        // save to pasteboard and open share-to-whatsapp flow
        UIPasteboard.general.image = image

        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "whatsapp://send?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - App availability

    func canOpenApp(_ scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
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
