import SwiftUI

struct AchievementRevealCard: View {
    let achievement: WalkAchievement
    let onDismiss: () -> Void

    @State private var isRevealed = false
    @State private var shimmer = false

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.color.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isRevealed ? 1.0 : 0.3)

                Image(systemName: achievement.icon)
                    .font(.system(size: 44))
                    .foregroundColor(achievement.color)
                    .scaleEffect(isRevealed ? 1.0 : 0)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: isRevealed)

            // Title
            Text("Achievement Unlocked!")
                .font(.caption)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundColor(.secondary)
                .opacity(isRevealed ? 1 : 0)

            Text(achievement.title)
                .font(.title2)
                .fontWeight(.bold)
                .opacity(isRevealed ? 1 : 0)

            Text(achievement.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .opacity(isRevealed ? 1 : 0)

            Button(action: onDismiss) {
                Text("Awesome!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(achievement.color)
                    )
            }
            .padding(.horizontal, 32)
            .opacity(isRevealed ? 1 : 0)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
                .shadow(radius: 16)
        )
        .padding(32)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isRevealed = true
            }
        }
    }
}
