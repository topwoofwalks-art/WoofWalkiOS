import SwiftUI

struct WalkPostCard: View {
    let post: Post
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void

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

            // Photo
            if let photoUrl = post.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill().frame(maxHeight: 250).clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: { Rectangle().fill(Color.neutral90).frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 8)) }
            }

            // Actions
            HStack(spacing: 24) {
                Button(action: onLike) {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .font(.subheadline)
                }
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
    }

    private func walkStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}
