import SwiftUI
import Charts

struct LandCoverChartView: View {
    let probabilities: LandCoverProbabilities
    let showLegend: Bool

    init(probabilities: LandCoverProbabilities, showLegend: Bool = true) {
        self.probabilities = probabilities
        self.showLegend = showLegend
    }

    private var chartData: [(name: String, value: Double, color: Color)] {
        [
            ("Water", probabilities.water, .blue),
            ("Trees", probabilities.trees, .green),
            ("Grass", probabilities.grass, Color(red: 0.5, green: 0.8, blue: 0.3)),
            ("Flooded Veg.", probabilities.floodedVegetation, Color(red: 0.3, green: 0.6, blue: 0.7)),
            ("Crops", probabilities.crops, Color(red: 0.9, green: 0.8, blue: 0.2)),
            ("Shrub & Scrub", probabilities.shrubAndScrub, Color(red: 0.6, green: 0.5, blue: 0.3)),
            ("Built", probabilities.built, .gray),
            ("Bare", probabilities.bare, Color(red: 0.7, green: 0.6, blue: 0.5)),
            ("Snow & Ice", probabilities.snowAndIce, .white)
        ].filter { $0.value > 0.01 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Land Cover Distribution")
                .font(.headline)
                .padding(.horizontal)

            if #available(iOS 16.0, *) {
                Chart(chartData, id: \.name) { item in
                    SectorMark(
                        angle: .value("Percentage", item.value * 100),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                    .opacity(0.8)
                }
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                pieChartFallback
            }

            if showLegend {
                legendView
            }
        }
    }

    private var pieChartFallback: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(chartData.enumerated()), id: \.offset) { index, item in
                    PieSlice(
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index),
                        color: item.color
                    )
                }
            }
            .frame(width: geometry.size.width, height: 200)
        }
        .frame(height: 200)
        .padding(.horizontal)
    }

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(chartData, id: \.name) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)

                    Text(item.name)
                        .font(.caption)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(String(format: "%.1f%%", item.value * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func startAngle(for index: Int) -> Angle {
        let sum = chartData.prefix(index).reduce(0.0) { $0 + $1.value }
        return .degrees(sum * 360)
    }

    private func endAngle(for index: Int) -> Angle {
        let sum = chartData.prefix(index + 1).reduce(0.0) { $0 + $1.value }
        return .degrees(sum * 360)
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.5

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle - .degrees(90),
            endAngle: endAngle - .degrees(90),
            clockwise: false
        )
        path.addLine(to: center)
        path.closeSubpath()

        return path
    }
}

struct SuitabilityScoreView: View {
    let suitability: LivestockSuitability
    let lastUpdated: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Livestock Suitability")
                .font(.headline)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: suitability.score / 100)
                        .stroke(
                            ratingColor(for: suitability.rating),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: suitability.score)

                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", suitability.score))
                            .font(.system(size: 28, weight: .bold))

                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(ratingColor(for: suitability.rating))
                            .frame(width: 12, height: 12)

                        Text(suitability.rating.description)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text("Primary: \(suitability.primaryType.capitalized)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Confidence: \(String(format: "%.0f%%", suitability.confidence * 100))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Updated: \(formatDate(lastUpdated))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    private func ratingColor(for rating: LivestockSuitability.SuitabilityRating) -> Color {
        switch rating {
        case .unknown: return .gray
        case .poor: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .excellent: return .green
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DynamicWorldDetailView: View {
    let data: DynamicWorldData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SuitabilityScoreView(
                    suitability: data.livestockSuitability,
                    lastUpdated: data.fetchedAt
                )
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)

                LandCoverChartView(probabilities: data.landCover)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)

                detailsSection

                if data.daysUntilExpiry > 0 {
                    expirationNotice
                }
            }
            .padding()
        }
        .navigationTitle("Field Analysis")
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Field Details")
                .font(.headline)

            LandCoverDetailRow(label: "Dominant Class", value: data.dominantClass.capitalized)
            LandCoverDetailRow(label: "Latitude", value: String(format: "%.6f", data.centerLat))
            LandCoverDetailRow(label: "Longitude", value: String(format: "%.6f", data.centerLng))

            if let radius = data.radiusMeters {
                LandCoverDetailRow(label: "Radius", value: String(format: "%.0f meters", radius))
            }

            LandCoverDetailRow(label: "Fetched", value: formatFullDate(data.fetchedAt))
            LandCoverDetailRow(label: "Expires", value: formatFullDate(data.expiresAt))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var expirationNotice: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.orange)

            Text("Data expires in \(data.daysUntilExpiry) days")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct LandCoverDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct LandCoverChartView_Previews: PreviewProvider {
    static var previews: some View {
        let probabilities = LandCoverProbabilities(
            water: 0.05,
            trees: 0.20,
            grass: 0.45,
            floodedVegetation: 0.02,
            crops: 0.15,
            shrubAndScrub: 0.08,
            built: 0.03,
            bare: 0.02,
            snowAndIce: 0.00
        )

        LandCoverChartView(probabilities: probabilities)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
