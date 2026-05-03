import SwiftUI

struct ActiveWalkBanner: View {
    let distance: Double // meters
    let duration: TimeInterval
    let isPaused: Bool
    let onTap: () -> Void

    /// Cumulative human step count for the active walk (from `MotionActivityService`).
    /// `nil` if motion permission is denied / pedometer unavailable — banner just hides
    /// the step tile in that case instead of showing 0.
    let humanSteps: Int?

    @State private var pulseAnimation = false

    /// Dog steps ≈ human steps × 2.5 (rough average over small/medium/large breeds).
    private var dogSteps: Int? {
        guard let humanSteps else { return nil }
        return Int(Double(humanSteps) * 2.5)
    }

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

                if let humanSteps {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(humanSteps)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .monospacedDigit()
                        if let dogSteps {
                            Image(systemName: "pawprint.fill")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text("\(dogSteps)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                                .monospacedDigit()
                        }
                    }
                }

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
