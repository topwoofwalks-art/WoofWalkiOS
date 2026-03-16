import SwiftUI
import MapKit

struct GuidancePanelView: View {
    let currentInstruction: String
    let nextInstruction: String?
    let distanceToNext: Double // meters
    let direction: DirectionType
    let totalDistance: Double // meters
    let totalDuration: TimeInterval
    let remainingDistance: Double // meters
    let remainingDuration: TimeInterval
    let walkDistance: Double // meters walked so far
    let walkDuration: TimeInterval // time walked
    let onDismiss: () -> Void

    var progress: Double {
        guard totalDistance > 0 else { return 0 }
        return min(walkDistance / totalDistance, 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Current direction
            HStack(spacing: 16) {
                DirectionIcon(direction: direction, size: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentInstruction)
                        .font(.headline)
                        .lineLimit(2)

                    if distanceToNext > 0 {
                        Text("in \(FormatUtils.formatDistance(distanceToNext))")
                            .font(.subheadline)
                            .foregroundColor(.turquoise60)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.neutral90)
                    Rectangle()
                        .fill(Color.turquoise60)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)

            // Stats row
            HStack(spacing: 20) {
                VStack {
                    Text(FormatUtils.formatDistance(remainingDistance))
                        .font(.callout)
                        .fontWeight(.bold)
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text(FormatUtils.formatDuration(Int(remainingDuration)))
                        .font(.callout)
                        .fontWeight(.bold)
                    Text("ETA")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack {
                    Text(FormatUtils.formatDistance(walkDistance))
                        .font(.callout)
                        .fontWeight(.bold)
                    Text("Walked")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text(FormatUtils.formatDurationCompact(Int(walkDuration)))
                        .font(.callout)
                        .fontWeight(.bold)
                    Text("Time")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)

            // Next instruction preview
            if let next = nextInstruction {
                Divider()
                HStack {
                    Text("Then:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(next)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.neutral95)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 4)
        )
    }
}
