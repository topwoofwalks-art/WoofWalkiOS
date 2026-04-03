import SwiftUI

struct ProfileGamificationSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            NavigationLink(destination: ChallengesScreen()) {
                Label("Challenges", systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: LeagueView()) {
                Label("Weekly League", systemImage: "trophy")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}
