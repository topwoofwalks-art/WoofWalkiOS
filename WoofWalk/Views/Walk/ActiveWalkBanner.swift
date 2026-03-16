import SwiftUI

struct ActiveWalkBanner: View {
    let distance: Double // meters
    let duration: TimeInterval
    let isPaused: Bool
    let onTap: () -> Void

    @State private var pulseAnimation = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Pulsing indicator
                Circle()
                    .fill(isPaused ? Color.orange60 : Color.green)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)

                Image(systemName: "figure.walk")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text(isPaused ? "Walk Paused" : "Walk in Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Spacer()

                Text(FormatUtils.formatDistance(distance))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .monospacedDigit()

                Text(FormatUtils.formatDurationCompact(Int(duration)))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPaused ? Color.orange60 : Color.turquoise60)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .onAppear { pulseAnimation = true }
    }
}
