import SwiftUI

struct WoofWalkBranding {
    static let appName = "WoofWalk"
    static let tagline = "Track walks. Share moments. Love dogs."
    static let websiteURL = "woofwalk.app"
    static let socialHandle = "@woofwalk"

    static let primaryColor = Color(red: 0/255, green: 160/255, blue: 176/255)
    static let primaryDark = Color(red: 0/255, green: 104/255, blue: 120/255)
    static let secondaryColor = Color(red: 255/255, green: 107/255, blue: 53/255)
    static let primaryLight = Color(red: 122/255, green: 213/255, blue: 222/255)

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [primaryDark, primaryColor, primaryLight],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func hashtags(distance: Double? = nil, dogBreed: String? = nil) -> [String] {
        var tags = ["#WoofWalk", "#DogWalk"]
        if let d = distance, d >= 5000 { tags.append("#LongWalk") }
        if let d = distance, d >= 10000 { tags.append("#Marathon") }
        if let breed = dogBreed { tags.append("#\(breed.replacingOccurrences(of: " ", with: ""))") }
        return tags
    }
}

struct ShareCardFooter: View {
    var body: some View {
        HStack {
            Image(systemName: "pawprint.fill")
                .foregroundColor(.white)
            Text(WoofWalkBranding.appName)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text(WoofWalkBranding.websiteURL)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(WoofWalkBranding.brandGradient)
    }
}

struct PawWatermarkOverlay: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 60
            let rows = Int(size.height / spacing) + 1
            let cols = Int(size.width / spacing) + 1
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing + (row % 2 == 0 ? 0 : spacing / 2)
                    let y = CGFloat(row) * spacing
                    if let paw = context.resolveSymbol(id: "paw") {
                        context.opacity = 0.08
                        context.draw(paw, at: CGPoint(x: x, y: y))
                    }
                }
            }
        } symbols: {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 20))
                .foregroundColor(.gray)
                .tag("paw")
        }
        .allowsHitTesting(false)
    }
}
