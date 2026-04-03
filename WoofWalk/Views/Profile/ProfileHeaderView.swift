import SwiftUI

struct ProfileHeaderView: View {
    let user: UserProfile

    var body: some View {
        VStack(spacing: 16) {
            if let photoUrl = user.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 100, height: 100)
            }

            VStack(spacing: 8) {
                Text(user.username)
                    .font(.title)
                    .fontWeight(.bold)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Level \(user.level)")
                            .font(.headline)
                    }

                    // League tier badge
                    leagueTierBadge(tier: user.leagueTier)
                }

                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .foregroundColor(.orange)
                    Text("\(user.pawPoints) points")
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func leagueTierBadge(tier: String?) -> some View {
        let resolvedTier = LeagueTier(rawValue: tier ?? "") ?? .bronze
        let color = leagueTierColor(resolvedTier)
        let name = resolvedTier.displayName

        return HStack(spacing: 4) {
            Image(systemName: "shield.fill")
                .foregroundColor(color)
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private func leagueTierColor(_ tier: LeagueTier) -> Color {
        switch tier {
        case .bronze: return Color(hex: 0xCD7F32)
        case .silver: return Color(hex: 0xC0C0C0)
        case .gold: return Color(hex: 0xFFD700)
        case .sapphire: return Color(hex: 0x0F52BA)
        case .ruby: return Color(hex: 0xE0115F)
        case .emerald: return Color(hex: 0x50C878)
        case .diamond: return Color(hex: 0xB9F2FF)
        }
    }
}
