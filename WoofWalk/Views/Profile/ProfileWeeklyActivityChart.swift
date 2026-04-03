import SwiftUI

struct ProfileWeeklyActivityChart: View {
    let weeklyWalkData: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 4) {
                        let height: CGFloat = weeklyWalkData.isEmpty ? 10 :
                            CGFloat(weeklyWalkData[index]) * 5 + 10
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(height: height)

                        Text(dayAbbreviation(index: index))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func dayAbbreviation(index: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][index]
    }
}
