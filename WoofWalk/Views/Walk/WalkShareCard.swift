import SwiftUI
import CoreLocation

struct WalkShareCard: View {
    let distance: Double // meters
    let duration: Int // seconds
    let pace: Double // min/km
    let steps: Int
    let dogNames: [String]
    let mapImage: UIImage?
    let date: Date
    let streakDays: Int
    let personalBests: [String] // e.g. ["Longest Distance", "Fastest Pace"]
    let charityPoints: Int

    var body: some View {
        VStack(spacing: 0) {
            // Map snapshot
            if let mapImage = mapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .aspectRatio(2.0, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.turquoise90)
                    .aspectRatio(2.0, contentMode: .fill)
                    .overlay {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.turquoise60)
                    }
            }

            VStack(spacing: 16) {
                // Dog names + date
                HStack {
                    VStack(alignment: .leading) {
                        Text(dogNames.joined(separator: " & "))
                            .font(.headline)
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange60)
                            Text("\(streakDays)")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange90))
                    }
                }

                // Main stats
                HStack(spacing: 0) {
                    shareStatColumn(value: FormatUtils.formatDistance(distance), label: "Distance")
                    Divider().frame(height: 40)
                    shareStatColumn(value: FormatUtils.formatDurationCompact(duration), label: "Duration")
                    Divider().frame(height: 40)
                    shareStatColumn(value: FormatUtils.formatPace(pace), label: "Pace")
                    if steps > 0 {
                        Divider().frame(height: 40)
                        shareStatColumn(value: "\(steps)", label: "Steps")
                    }
                }

                // Personal bests
                if !personalBests.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(personalBests, id: \.self) { pb in
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(pb)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.yellow.opacity(0.15)))
                        }
                    }
                }

                // Charity
                if charityPoints > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                        Text("\(charityPoints) charity points donated")
                            .font(.caption)
                    }
                }

                // Branding
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "pawprint.fill")
                            .font(.caption)
                            .foregroundColor(.turquoise60)
                        Text("WoofWalk")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.turquoise60)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 4)
    }

    private func shareStatColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
