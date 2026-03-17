import SwiftUI

struct LevelUpToast: View {
    let newLevel: Int
    let bonusPoints: Int
    let onDismiss: () -> Void

    @State private var isShowing = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Confetti behind the card
            if showConfetti {
                ConfettiEffect(variant: .gold)
                    .allowsHitTesting(false)
            }

            // Toast card
            VStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.84, blue: 0.0),
                                Color(red: 0.85, green: 0.65, blue: 0.13),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .wiggle()

                Text("Level Up!")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text("Level \(newLevel)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.accentColor)

                if bonusPoints > 0 {
                    Text("+\(bonusPoints) bonus points")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .goldBorder(cornerRadius: 24)
            .scaleReveal()
            .offset(y: isShowing ? 0 : 300)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.7),
                value: isShowing
            )
        }
        .onAppear {
            HapticFeedback.levelUp()
            isShowing = true
            showConfetti = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeIn(duration: 0.3)) {
                    isShowing = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onDismiss()
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.3).ignoresSafeArea()
        LevelUpToast(newLevel: 12, bonusPoints: 50, onDismiss: {})
    }
}
