import SwiftUI
import MapKit

struct WalkPostCard: View {
    let post: Post
    let onReaction: (ReactionType) -> Void
    let onComment: () -> Void
    let onShare: () -> Void

    @State private var showReactionPicker = false
    /// Index of the photo whose comment sheet is open, or nil when closed.
    /// Long-pressing any photo in a multi-image gallery opens this sheet
    /// scoped to that photo (mirrors PhotoCommentSheet.kt on Android).
    @State private var photoCommentIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author header
            HStack(spacing: 10) {
                Circle().fill(Color.neutral90).frame(width: 40, height: 40)
                    .overlay {
                        if let url = post.authorAvatar, let imgUrl = URL(string: url) {
                            AsyncImage(url: imgUrl) { img in img.resizable().scaledToFill() } placeholder: { Color.clear }
                                .clipShape(Circle())
                        } else {
                            Text(String(post.authorName.prefix(1))).font(.headline)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName).font(.subheadline.bold())
                    if let date = post.createdAt?.dateValue() {
                        Text(FormatUtils.formatRelativeTime(date)).font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let tag = post.locationTag {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill").font(.caption2)
                        Text(tag).font(.caption2)
                    }.foregroundColor(.secondary)
                }
            }

            // Text content
            if !post.text.isEmpty {
                Text(post.text).font(.body)
            }

            // Dog avatar row
            dogAvatarRow

            // Walk data
            if let walk = post.walkData {
                HStack(spacing: 16) {
                    walkStat(value: FormatUtils.formatDistance(walk.distance), label: "Distance")
                    walkStat(value: FormatUtils.formatDuration(walk.duration), label: "Duration")
                    if walk.steps > 0 { walkStat(value: "\(walk.steps)", label: "Steps") }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.turquoise90.opacity(0.3)))
            }

            // Route polyline thumbnail
            routeThumbnail

            // Photos. Multi-image posts use `media[]`; long-pressing any
            // photo opens that photo's PhotoCommentSheet. Legacy posts that
            // only have `photoUrl` render as a single image and long-press
            // opens index 0.
            photoGallery

            // Reaction summary
            if let reactions = post.reactions, !reactions.isEmpty {
                ReactionSummary(reactions: reactions)
                    .padding(.top, 2)
            }

            // Actions
            HStack(spacing: 24) {
                Button(action: onComment) {
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                        .font(.subheadline)
                }
                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                Spacer()
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
        .overlay(alignment: .bottom) {
            if showReactionPicker {
                ReactionPicker(
                    onReaction: { type in
                        onReaction(type)
                    },
                    isPresented: $showReactionPicker
                )
                .offset(y: -8)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showReactionPicker = true
            }
        }
        .onTapGesture {
            if showReactionPicker {
                withAnimation(.easeOut(duration: 0.15)) {
                    showReactionPicker = false
                }
            }
        }
        .sheet(item: $photoCommentIndex.wrappedAsIdentifiable) { wrapper in
            PhotoCommentSheet(post: post, photoIndex: wrapper.value)
        }
    }

    // MARK: - Photo Gallery

    /// Renders either:
    ///   - multi-image gallery when `post.media` has >1 entries (horizontal
    ///     scroll, each photo long-pressable for per-photo comments), or
    ///   - single image when only `photoUrl` (legacy shape) is set
    ///     (long-press opens comments for photoIndex 0).
    /// Nothing renders when the post has no images at all.
    @ViewBuilder
    private var photoGallery: some View {
        if let media = post.media, !media.isEmpty {
            if media.count == 1 {
                photoTile(urlStr: media[0].url, photoIndex: 0)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(media.enumerated()), id: \.offset) { idx, item in
                            photoTile(urlStr: item.url, photoIndex: idx)
                                .frame(width: 240, height: 240)
                        }
                    }
                }
                .frame(height: 240)
            }
        } else if let photoUrl = post.photoUrl {
            photoTile(urlStr: photoUrl, photoIndex: 0)
        }
    }

    private func photoTile(urlStr: String, photoIndex: Int) -> some View {
        Group {
            if let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.neutral90)
                }
            } else {
                Rectangle().fill(Color.neutral90)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 250)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onLongPressGesture(minimumDuration: 0.4) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            self.photoCommentIndex = photoIndex
        }
    }

    // MARK: - Dog Avatar Row

    @ViewBuilder
    private var dogAvatarRow: some View {
        if let walk = post.walkData, let photos = walk.dogPhotoUrls, !photos.isEmpty {
            HStack(spacing: -8) {
                ForEach(Array(photos.prefix(4).enumerated()), id: \.offset) { index, urlString in
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.turquoise90.opacity(0.5))
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .zIndex(Double(photos.count - index))
                    }
                }
                if let names = post.walkData?.dogNames, !names.isEmpty {
                    Text(names.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
            }
        }
    }

    // MARK: - Route Thumbnail

    @ViewBuilder
    private var routeThumbnail: some View {
        if let walk = post.walkData, let points = walk.routePoints, points.count >= 2 {
            let coords = points.compactMap { dict -> CLLocationCoordinate2D? in
                guard let lat = dict["lat"] ?? dict["latitude"],
                      let lng = dict["lng"] ?? dict["longitude"] else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
            if coords.count >= 2 {
                RoutePolylineView(coordinates: coords)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } else if let thumbUrl = post.routeMapThumbnailUrl, let url = URL(string: thumbUrl) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.neutral90.opacity(0.3))
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Helpers

    private func walkStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MARK: - Int identifiable wrapper

/// SwiftUI's `sheet(item:)` needs an Identifiable binding; wrap an `Int?`
/// so the photo index can drive the per-photo comment sheet without
/// promoting it to its own boxed state type at every callsite.
private struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}

private extension Binding where Value == Int? {
    var wrappedAsIdentifiable: Binding<IdentifiableInt?> {
        Binding<IdentifiableInt?>(
            get: { self.wrappedValue.map(IdentifiableInt.init(value:)) },
            set: { self.wrappedValue = $0?.value }
        )
    }
}

// MARK: - Route Polyline Map

struct RoutePolylineView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.delegate = context.coordinator
        mapView.overrideUserInterfaceStyle = .light
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        var region = MKCoordinateRegion(polyline.boundingMapRect)
        region.span.latitudeDelta *= 1.4
        region.span.longitudeDelta *= 1.4
        mapView.setRegion(region, animated: false)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemTeal
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
