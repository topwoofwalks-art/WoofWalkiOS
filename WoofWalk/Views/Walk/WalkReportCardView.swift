import SwiftUI

struct WalkReportCardView: View {
    let distance: Double
    let duration: Int
    let pace: Double
    let steps: Int
    let dogNames: [String]
    let comparison: WalkComparison?
    let personalBest: PersonalBestResult?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Walk Report")
                        .font(.title2.bold())
                    Text(dogNames.joined(separator: " & "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "pawprint.fill")
                    .font(.title)
                    .foregroundColor(.turquoise60)
            }

            Divider()

            // Main stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                reportStat(icon: "figure.walk", label: "Distance", value: FormatUtils.formatDistance(distance))
                reportStat(icon: "clock", label: "Duration", value: FormatUtils.formatDuration(duration))
                reportStat(icon: "speedometer", label: "Avg Pace", value: FormatUtils.formatPace(pace))
                if steps > 0 { reportStat(icon: "shoeprints.fill", label: "Steps", value: "\(steps)") }
            }

            // Route comparison
            if let comp = comparison, comp.hasPlannedRoute {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Route Comparison").font(.headline)
                    HStack {
                        Text("Route adherence").font(.caption)
                        Spacer()
                        Text(String(format: "%.0f%%", comp.routeAdherencePercent)).font(.caption.bold())
                    }
                    ProgressView(value: comp.routeAdherencePercent / 100.0)
                        .tint(.turquoise60)
                }
            }

            // Personal best
            if let pb = personalBest {
                PersonalBestBanner(result: pb)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 2))
    }

    private func reportStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.turquoise60)
                .frame(width: 28)
            VStack(alignment: .leading) {
                Text(value).font(.headline)
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
