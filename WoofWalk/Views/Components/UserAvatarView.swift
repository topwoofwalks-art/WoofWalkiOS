import SwiftUI

/// Single source of truth for user/member avatar rendering across every screen.
///
/// Renders the user's `photoUrl` from Firestore (`users/{uid}.photoURL`) when
/// available, falling back to a deterministic coloured circle with the user's
/// initials when null/blank or while the image is loading/failing. The
/// background colour is derived from the display name hash so the same user
/// always gets the same colour — recognisable across screens.
///
/// Use this everywhere a user/member is shown: leaderboard rows, post authors,
/// comment authors, member lists, chat headers/bubbles, friend lists,
/// watcher lists, attendees, organisers, notifications, etc.
struct UserAvatarView: View {
    let photoUrl: String?
    let displayName: String
    let size: CGFloat

    init(photoUrl: String?, displayName: String, size: CGFloat = 36) {
        self.photoUrl = photoUrl
        self.displayName = displayName
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)

            initialsLabel

            if let urlString = photoUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure, .empty:
                        Color.clear
                    @unknown default:
                        Color.clear
                    }
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }

    private var initialsLabel: some View {
        Text(initials)
            .font(.system(size: max(size * 0.42, 10), weight: .semibold))
            .foregroundColor(.white)
    }

    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let words = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        switch words.count {
        case 0: return "?"
        case 1: return String(words[0].prefix(1)).uppercased()
        default:
            let first = words.first.map { String($0.prefix(1)) } ?? ""
            let last = words.last.map { String($0.prefix(1)) } ?? ""
            return (first + last).uppercased()
        }
    }

    private var backgroundColor: Color {
        guard !displayName.isEmpty else { return UserAvatarView.palette[0] }
        var hash = 0
        for ch in displayName.unicodeScalars { hash = hash &* 31 &+ Int(ch.value) }
        let idx = ((hash % UserAvatarView.palette.count) + UserAvatarView.palette.count) % UserAvatarView.palette.count
        return UserAvatarView.palette[idx]
    }

    private static let palette: [Color] = [
        Color(red: 0.36, green: 0.54, blue: 0.90),
        Color(red: 0.90, green: 0.49, blue: 0.36),
        Color(red: 0.42, green: 0.71, blue: 0.45),
        Color(red: 0.72, green: 0.36, blue: 0.71),
        Color(red: 0.90, green: 0.72, blue: 0.36),
        Color(red: 0.36, green: 0.71, blue: 0.71),
        Color(red: 0.71, green: 0.41, blue: 0.36),
        Color(red: 0.54, green: 0.36, blue: 0.71),
        Color(red: 0.36, green: 0.71, blue: 0.53),
        Color(red: 0.71, green: 0.36, blue: 0.54)
    ]
}
