import SwiftUI

struct ProfileBadgesSection: View {
    let badges: [BadgeWithStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(badges.prefix(6), id: \.badge.id) { badgeStatus in
                    BadgeView(badgeStatus: badgeStatus)
                }
            }

            NavigationLink(destination: BadgesListView(badges: badges)) {
                Text("View All Badges")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}
