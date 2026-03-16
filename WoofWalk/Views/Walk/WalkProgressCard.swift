import SwiftUI

struct WalkProgressCard: View {
    let distance: Double
    let duration: TimeInterval
    let pace: Double
    let isPaused: Bool
    let streakDays: Int
    let onStopWalk: () -> Void

    init(distance: Double, duration: TimeInterval, pace: Double = 0, isPaused: Bool = false, streakDays: Int = 0, onStopWalk: @escaping () -> Void) {
        self.distance = distance; self.duration = duration; self.pace = pace; self.isPaused = isPaused; self.streakDays = streakDays; self.onStopWalk = onStopWalk
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .foregroundColor(.turquoise60)
                        Text(isPaused ? "Paused" : "Walking")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isPaused ? .orange60 : .turquoise60)

                        if streakDays > 0 {
                            Text("\(streakDays) day streak")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange60.opacity(0.2)))
                                .foregroundColor(.orange60)
                        }
                    }

                    HStack(spacing: 16) {
                        Text(FormatUtils.formatDistance(distance))
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()

                        Text(FormatUtils.formatDurationCompact(Int(duration)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()

                        if pace > 0 {
                            Text(FormatUtils.formatPace(pace))
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Button(action: onStopWalk) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.red))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(radius: 2)
        )
    }
}
