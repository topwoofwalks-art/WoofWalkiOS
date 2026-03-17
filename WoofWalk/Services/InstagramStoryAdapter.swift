import UIKit

struct InstagramStoryAdapter {
    /// Adapts a 4:5 share card image onto a 9:16 Instagram Stories canvas
    /// with branded gradient background and WoofWalk branding.
    static func adapt(cardImage: UIImage) -> UIImage? {
        let canvasWidth: CGFloat = 1080
        let canvasHeight: CGFloat = 1920 // 9:16

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))
        return renderer.image { context in
            let ctx = context.cgContext

            // Branded gradient background (#0A1628 → #1B2838)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 10/255, green: 22/255, blue: 40/255, alpha: 1).cgColor,
                UIColor(red: 27/255, green: 40/255, blue: 56/255, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: canvasWidth / 2, y: 0),
                    end: CGPoint(x: canvasWidth / 2, y: canvasHeight),
                    options: []
                )
            }

            // "WoofWalk" text at top
            let topText = "WoofWalk" as NSString
            let topAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let topSize = topText.size(withAttributes: topAttrs)
            topText.draw(
                at: CGPoint(x: (canvasWidth - topSize.width) / 2, y: 80),
                withAttributes: topAttrs
            )

            // Center the card image vertically on canvas
            let cardWidth = canvasWidth - 80 // 40pt padding each side
            let cardHeight = cardWidth * (5.0 / 4.0) // maintain 4:5 ratio
            let cardX: CGFloat = 40
            let cardY = (canvasHeight - cardHeight) / 2
            let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)

            // Draw rounded card with shadow
            ctx.saveGState()
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 24)
            ctx.setShadow(offset: CGSize(width: 0, height: 4), blur: 20, color: UIColor.black.withAlphaComponent(0.4).cgColor)
            cardPath.addClip()
            cardImage.draw(in: cardRect)
            ctx.restoreGState()

            // "woofwalk.app" text at bottom
            let bottomText = "woofwalk.app" as NSString
            let bottomAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            ]
            let bottomSize = bottomText.size(withAttributes: bottomAttrs)
            bottomText.draw(
                at: CGPoint(x: (canvasWidth - bottomSize.width) / 2, y: canvasHeight - 100),
                withAttributes: bottomAttrs
            )
        }
    }
}
