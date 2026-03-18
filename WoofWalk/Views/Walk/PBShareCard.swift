import SwiftUI

struct PBMetric: Identifiable {
    let id = UUID()
    let name: String
    let newValue: String
    let improvementPercent: Double
}

struct PBShareCard: View {
    let dogName: String
    let date: Date
    let metrics: [PBMetric]
    let totalWalks: Int
    let totalDistance: Double // meters

    private let goldLight = Color(red: 1.0, green: 215/255, blue: 0) // #FFD700
    private let goldDark = Color(red: 218/255, green: 165/255, blue: 32/255) // #DAA520
    private let darkBg = Color(red: 26/255, green: 26/255, blue: 46/255) // #1A1A2E

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(20)
                .background(darkBg)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [goldLight, goldDark, goldLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
        )
        .cornerRadius(16)
        .shadow(color: goldLight.opacity(0.3), radius: 8)
    }

    private var content: some View {
        VStack(spacing: 16) {
            trophyCluster
            headline
            dogLabel
            pbRows
            Divider().overlay(goldDark.opacity(0.3))
            bottomStats
            brandingFooter
        }
    }

    private var trophyCluster: some View {
        HStack(spacing: -8) {
            ForEach(0..<min(metrics.count + 2, 5), id: \.self) { i in
                Image(systemName: "trophy.fill")
                    .font(.system(size: i == metrics.count / 2 + 1 ? 32 : 24))
                    .foregroundStyle(
                        LinearGradient(colors: [goldLight, goldDark], startPoint: .top, endPoint: .bottom)
                    )
            }
        }
    }

    private var headline: some View {
        Text("NEW PERSONAL BEST!")
            .font(.title2)
            .fontWeight(.black)
            .foregroundStyle(
                LinearGradient(colors: [goldLight, goldDark], startPoint: .leading, endPoint: .trailing)
            )
    }

    private var dogLabel: some View {
        VStack(spacing: 2) {
            Text(dogName)
                .font(.headline)
                .foregroundColor(.white)
            Text(date, style: .date)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private var pbRows: some View {
        VStack(spacing: 10) {
            ForEach(metrics) { metric in
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(goldLight)
                    Text(metric.name)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(metric.newValue)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("+\(Int(metric.improvementPercent))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            }
        }
    }

    private var bottomStats: some View {
        HStack {
            statBadge(value: "\(totalWalks)", label: "Walks")
            Spacer()
            statBadge(value: FormatUtils.formatDistance(totalDistance), label: "Total Dist")
        }
        .padding(.horizontal, 4)
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var brandingFooter: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill")
                    .font(.caption)
                Text("WoofWalk")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundStyle(
                LinearGradient(colors: [goldLight, goldDark], startPoint: .leading, endPoint: .trailing)
            )
        }
    }

    // MARK: - Render to shareable image (1080x1350, 4:5)

    /// Renders this PB share card to a UIImage at social-media resolution (1080x1350).
    /// Uses the View.renderToImage extension from ShareService.
    func renderToImage() -> UIImage {
        self.renderToImage(size: ShareCardSize.socialMedia)
    }
}
