import SwiftUI

struct MilestoneCelebration: View {
    let milestone: DogMilestone
    let dogName: String
    let onDismiss: () -> Void

    @State private var isShowing = false

    var body: some View {
        VStack(spacing: 24) {
            // Trophy icon
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundColor(.yellow)
                .scaleEffect(isShowing ? 1.0 : 0.3)
                .animation(.spring(response: 0.5, dampingFraction: 0.5), value: isShowing)

            VStack(spacing: 8) {
                Text("Milestone Reached!")
                    .font(.caption)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundColor(.secondary)

                Text(milestone.title)
                    .font(.title)
                    .fontWeight(.bold)

                Text("\(dogName) - \(milestone.subtitle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .opacity(isShowing ? 1 : 0)

            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.turquoise60)
                Text("+\(milestone.pawPointsBonus) Paw Points")
                    .fontWeight(.bold)
                    .foregroundColor(.turquoise60)
            }
            .font(.headline)
            .opacity(isShowing ? 1 : 0)

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
            }
            .padding(.horizontal, 32)
            .opacity(isShowing ? 1 : 0)
        }
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 24).fill(.regularMaterial).shadow(radius: 16))
        .padding(32)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { isShowing = true }
        }
    }
}
