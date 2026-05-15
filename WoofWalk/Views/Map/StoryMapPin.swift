import SwiftUI
import CoreLocation

// MARK: - StoryPin Model
//
// Parity counterpart of Android `StoryMapPins.kt` — surfaces a
// geotagged story on the live map as a circular avatar annotation.
// The Android renderer paints a gradient ring around unviewed
// stories (Instagram-style); iOS uses the system accent colour for
// the ring since the gradient render is part of the bitmap-marker
// path that isn't applicable to SwiftUI's MapAnnotation.
struct StoryPin: Identifiable, Equatable {
    let storyId: String
    let coordinate: CLLocationCoordinate2D
    let posterUid: String
    let posterName: String
    let posterPhotoUrl: URL?
    let thumbnailUrl: URL?

    var id: String { storyId }

    static func == (lhs: StoryPin, rhs: StoryPin) -> Bool {
        lhs.storyId == rhs.storyId &&
        lhs.posterUid == rhs.posterUid &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

// MARK: - StoryMapPinView
//
// The annotation view rendered on the map for a single story pin.
// Mirrors the Android bitmap-marker shape: circular thumbnail (or
// avatar fallback), gradient/accent ring, paw badge in bottom-right.
struct StoryMapPinView: View {
    let pin: StoryPin

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                // Gradient ring — Instagram-style hot-pink → orange
                // wash for active stories. Always-coloured on iOS;
                // we don't carry the per-user viewed-state in the
                // pin doc (the StoryViewer marks-seen on open).
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color(red: 0.91, green: 0.12, blue: 0.39), // pink
                                Color(red: 0.96, green: 0.26, blue: 0.21), // red
                                Color(red: 1.00, green: 0.60, blue: 0.00), // orange
                                Color(red: 0.91, green: 0.12, blue: 0.39)
                            ],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 44, height: 44)

                // White inner padding
                Circle()
                    .fill(Color.white)
                    .frame(width: 38, height: 38)

                avatar
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
            }

            // Paw badge bottom-right
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: 16, height: 16)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(x: 2, y: 2)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = pin.thumbnailUrl ?? pin.posterPhotoUrl {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "person.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
        }
    }
}
