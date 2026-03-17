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
            currentDirectionRow
            progressBar
            statsRow
            nextInstructionPreview
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 4)
        )
    }

    // MARK: - Sub-views

    private var currentDirectionRow: some View {
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
    }

    private var progressBar: some View {
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
    }

    private var statsRow: some View {
        HStack(spacing: 20) {
            statItem(value: FormatUtils.formatDistance(remainingDistance), label: "Remaining")
            statItem(value: FormatUtils.formatDuration(Int(remainingDuration)), label: "ETA")
            Spacer()
            statItem(value: FormatUtils.formatDistance(walkDistance), label: "Walked")
            statItem(value: FormatUtils.formatDurationCompact(Int(walkDuration)), label: "Time")
        }
        .padding(12)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack {
            Text(value)
                .font(.callout)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var nextInstructionPreview: some View {
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
}
