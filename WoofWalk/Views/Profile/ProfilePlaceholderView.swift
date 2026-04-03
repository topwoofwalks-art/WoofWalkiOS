import SwiftUI

struct ProfilePlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Avatar placeholder
            Circle()
                .fill(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0/255, green: 160/255, blue: 176/255))
                )

            Text("Welcome to WoofWalk")
                .font(.title2.bold())

            Text("Sign in to see your profile")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Demo stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Walks", value: "0", icon: "figure.walk", color: .blue)
                StatCard(title: "Distance", value: "0 km", icon: "map", color: .green)
                StatCard(title: "Time", value: "0h", icon: "clock", color: .orange)
                StatCard(title: "Points", value: "0", icon: "star.fill", color: .purple)
            }
            .padding(.horizontal)

            // Sign in prompt
            Button(action: {}) {
                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(red: 0/255, green: 160/255, blue: 176/255)))
            }
            .padding(.top, 8)

            // Feature highlights
            VStack(alignment: .leading, spacing: 12) {
                Text("What you can do")
                    .font(.headline)
                    .padding(.horizontal)

                featureRow(icon: "figure.walk", color: .blue, title: "Track Walks", desc: "GPS-tracked walks with stats")
                featureRow(icon: "trophy.fill", color: .orange, title: "Earn Badges", desc: "Complete challenges and level up")
                featureRow(icon: "person.3.fill", color: .purple, title: "Join Community", desc: "Share walks and connect with walkers")
                featureRow(icon: "map.fill", color: .green, title: "Discover Places", desc: "Find dog-friendly pubs, parks & vets")
            }
            .padding(.top, 8)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(color.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}
