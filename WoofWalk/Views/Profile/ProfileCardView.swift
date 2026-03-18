import SwiftUI

struct ProfileCardView: View {
    let userName: String
    let level: Int
    let pawPoints: Int
    let leagueName: String
    let walkCount: Int
    let followerCount: Int
    let followingCount: Int
    let onEditProfile: () -> Void

    private let bannerHeight: CGFloat = 120
    private let avatarSize: CGFloat = 100

    private var leagueTier: LeagueTier {
        LeagueTier(rawValue: leagueName.uppercased()) ?? .bronze
    }

    private var leagueColor: Color {
        leagueTier.tierGradientColors.first ?? Color(hex: 0xCD7F32)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Banner + Avatar overlay
            ZStack(alignment: .bottom) {
                // Teal/turquoise gradient banner
                LinearGradient(
                    colors: [Color.turquoise40, Color.turquoise60, Color.turquoise70],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: bannerHeight)

                // Avatar circle, overlapping the banner bottom edge
                avatarView
                    .offset(y: avatarSize / 2)
            }

            // Spacer for the avatar overhang
            Spacer()
                .frame(height: avatarSize / 2 + 8)

            // Level badge
            Text("LVL \(level)")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange60))
                .padding(.bottom, 8)

            // User name
            Text(userName)
                .font(.title3.bold())
                .foregroundColor(Color.neutral90)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Paw Points
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.subheadline)
                    .foregroundColor(Color.orange60)
                Text("\(pawPoints) Paw Points")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.orange60)
            }
            .padding(.top, 4)

            // League badge
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.caption)
                    .foregroundColor(leagueColor)
                Text(leagueTier.displayName + " League")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(leagueColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(leagueColor.opacity(0.15)))
            .padding(.top, 8)

            // Edit Profile button
            Button(action: onEditProfile) {
                Text("Edit Profile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.turquoise70)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(Color.turquoise70, lineWidth: 1.5)
                    )
            }
            .padding(.top, 12)

            // Stats row
            HStack(spacing: 0) {
                statItem(value: walkCount, label: "Walks")
                divider
                statItem(value: followerCount, label: "Followers")
                divider
                statItem(value: followingCount, label: "Following")
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(Color.neutral20)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Avatar

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color.neutral10)
                .frame(width: avatarSize, height: avatarSize)

            Circle()
                .stroke(Color.neutral20, lineWidth: 4)
                .frame(width: avatarSize, height: avatarSize)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 36))
                .foregroundColor(Color.turquoise60)
        }
    }

    // MARK: - Stats

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.subheadline.bold())
                .foregroundColor(Color.neutral90)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.neutral60)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.neutral40)
            .frame(width: 1, height: 28)
    }
}

// MARK: - Preview

struct ProfileCardView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            ProfileCardView(
                userName: "Bret Hunter Gordon",
                level: 2,
                pawPoints: 242,
                leagueName: "BRONZE",
                walkCount: 113,
                followerCount: 0,
                followingCount: 0,
                onEditProfile: {}
            )
            .padding()
        }
        .background(Color.neutral10)
        .preferredColorScheme(.dark)
    }
}
