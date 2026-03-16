import SwiftUI

struct WalkControlPanel: View {
    let isWalking: Bool
    let isPaused: Bool
    let distance: Double // meters
    let duration: TimeInterval
    let currentPace: Double // min/km
    let averagePace: Double // min/km
    let onPause: () -> Void
    let onResume: () -> Void
    let onStop: () -> Void
    let onAddPhoto: () -> Void
    let onMarkWaste: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 20) {
                StatItem(title: "Distance", value: FormatUtils.formatDistance(distance))
                StatItem(title: "Time", value: FormatUtils.formatDurationCompact(Int(duration)))
                StatItem(title: "Pace", value: FormatUtils.formatPace(averagePace))
            }
            .padding(.horizontal)

            // Current pace indicator
            if isWalking && !isPaused {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.turquoise60)
                    Text("Current: \(FormatUtils.formatPace(currentPace))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isPaused {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(.orange60)
                    Text("Walk Paused")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange60)
                }
                .padding(.vertical, 4)
            }

            // Control buttons
            HStack(spacing: 16) {
                // Photo button
                Button(action: onAddPhoto) {
                    VStack {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                        Text("Photo")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.turquoise60))
                }

                // Waste marker
                if let onMarkWaste = onMarkWaste {
                    Button(action: onMarkWaste) {
                        VStack {
                            Image(systemName: "leaf.fill")
                                .font(.title3)
                            Text("Waste")
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.green))
                    }
                }

                Spacer()

                // Pause/Resume
                Button(action: isPaused ? onResume : onPause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(isPaused ? Color.turquoise60 : Color.orange60))
                }

                // Stop
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color.red))
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 4)
        )
    }
}

struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
