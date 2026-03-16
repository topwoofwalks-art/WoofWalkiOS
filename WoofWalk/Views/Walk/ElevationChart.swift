import SwiftUI
import Charts

struct ElevationChart: View {
    let elevationPoints: [(distance: Double, elevation: Double)]
    let totalGain: Double
    let totalLoss: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elevation").font(.headline)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up").foregroundColor(.green)
                    Text("\(Int(totalGain))m gain").font(.caption)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down").foregroundColor(.red)
                    Text("\(Int(totalLoss))m loss").font(.caption)
                }
            }

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(elevationPoints.enumerated()), id: \.offset) { index, point in
                        AreaMark(
                            x: .value("Distance", point.distance),
                            y: .value("Elevation", point.elevation)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.turquoise60.opacity(0.3), Color.turquoise60.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Distance", point.distance),
                            y: .value("Elevation", point.elevation)
                        )
                        .foregroundStyle(Color.turquoise60)
                    }
                }
                .frame(height: 150)
                .chartXAxisLabel("Distance (km)")
                .chartYAxisLabel("Elevation (m)")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }
}
