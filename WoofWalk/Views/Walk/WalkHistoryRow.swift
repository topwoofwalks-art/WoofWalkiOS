import SwiftUI

struct WalkHistoryRow: View {
    let date: Date
    let distance: Double  // meters
    let duration: Int     // seconds
    let dogNames: [String]

    var body: some View {
        HStack(spacing: 12) {
            // Date circle
            VStack(spacing: 2) {
                Text(date, format: .dateTime.day())
                    .font(.title3.bold())
                Text(date, format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color(red: 0/255, green: 160/255, blue: 176/255).opacity(0.1)))

            VStack(alignment: .leading, spacing: 4) {
                Text(dogNames.isEmpty ? "Walk" : dogNames.joined(separator: " & "))
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    Label(FormatUtils.formatDistance(distance), systemImage: "figure.walk")
                    Label(FormatUtils.formatDuration(duration), systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        WalkHistoryRow(
            date: Date(),
            distance: 2450,
            duration: 1800,
            dogNames: ["Buddy", "Max"]
        )
        WalkHistoryRow(
            date: Date().addingTimeInterval(-86400),
            distance: 800,
            duration: 600,
            dogNames: []
        )
    }
}
