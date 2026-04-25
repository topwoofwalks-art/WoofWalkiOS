import SwiftUI

/// Single source of truth for "logo or placeholder" rendering across discovery,
/// claim flow, and provider detail surfaces.
///
/// Fallback rules:
///   1. `photoUrl` resolves to a URL → render the remote image (AsyncImage).
///   2. No URL, business is external/unclaimed → dashed-border "awaiting
///      invite" placeholder (BusinessPlaceholderAwaitingInvite asset).
///   3. No URL, WoofWalk-listed business with no logo uploaded yet →
///      clean paw placeholder (BusinessPlaceholderNoLogo asset).
struct BusinessAvatarView: View {
    let photoUrl: String?
    let isExternal: Bool
    let size: CGFloat
    let cornerRadius: CGFloat

    init(photoUrl: String?, isExternal: Bool = false, size: CGFloat = 40, cornerRadius: CGFloat? = nil) {
        self.photoUrl = photoUrl
        self.isExternal = isExternal
        self.size = size
        self.cornerRadius = cornerRadius ?? (size / 2) // default: circle
    }

    var body: some View {
        Group {
            if let urlString = photoUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        Image(isExternal ? "BusinessPlaceholderAwaitingInvite" : "BusinessPlaceholderNoLogo")
            .resizable()
            .scaledToFill()
    }
}
