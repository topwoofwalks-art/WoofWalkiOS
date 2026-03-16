import UIKit
import SwiftUI

@MainActor
class ShareService {
    static let shared = ShareService()

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
        default:
            shareImage(image, text: text)
        }
    }
}
