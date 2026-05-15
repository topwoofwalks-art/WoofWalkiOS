import SwiftUI

/// Planned-vs-Actual cell rendered on the walk recap when a planned route
/// was attached to the walk. Mirrors `WalkCompletionScreen.kt:318-392` —
/// labelled row showing planned value, actual value, and a delta arrow
/// coloured by direction (green when the user came in under the plan on
/// distance/duration, red when over). The "good" direction is configurable
/// because for route adherence and POI visits, higher is better while for
/// duration/distance lower-than-planned is the typical positive outcome.
struct ComparisonMetricCard: View {
    enum DeltaDirection {
        /// Lower actual than planned reads as positive (e.g. faster walk).
        case lowerIsBetter
        /// Higher actual than planned reads as positive (e.g. adherence).
        case higherIsBetter
        /// No colouring — just show the arrow neutrally.
        case neutral
    }

    let title: String
    let planned: String
    let actual: String
    /// % difference of actual vs planned, signed: + = actual > planned.
    /// Pass nil to suppress the delta column entirely (used when the value
    /// pair doesn't have a meaningful percentage relationship).
    let diffPercent: Double?
    let direction: DeltaDirection

    init(
        title: String,
        planned: String,
        actual: String,
        diffPercent: Double?,
        direction: DeltaDirection = .lowerIsBetter
    ) {
        self.title = title
        self.planned = planned
        self.actual = actual
        self.diffPercent = diffPercent
        self.direction = direction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
            HStack(spacing: 12) {
                metricCell(label: "Planned", value: planned)
                Divider().frame(height: 28)
                metricCell(label: "Actual", value: actual)
                if let diff = diffPercent {
                    Divider().frame(height: 28)
                    deltaCell(diff: diff)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deltaCell(diff: Double) -> some View {
        let isPositive = diff > 0
        let isNegative = diff < 0
        let colour: Color = {
            switch direction {
            case .lowerIsBetter:
                if isPositive { return .red }
                if isNegative { return .green }
                return .secondary
            case .higherIsBetter:
                if isPositive { return .green }
                if isNegative { return .red }
                return .secondary
            case .neutral:
                return .secondary
            }
        }()
        let arrow: String = {
            if isPositive { return "arrow.up" }
            if isNegative { return "arrow.down" }
            return "equal"
        }()
        return VStack(alignment: .leading, spacing: 2) {
            Text("Δ").font(.caption2).foregroundColor(.secondary)
            HStack(spacing: 2) {
                Image(systemName: arrow).font(.caption2)
                Text(String(format: "%.0f%%", abs(diff)))
                    .font(.subheadline.bold())
            }
            .foregroundColor(colour)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
