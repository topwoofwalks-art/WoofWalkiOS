import SwiftUI

struct PersonalBestBanner: View {
    let result: PersonalBestResult
    @State private var isShowing = false

    var body: some View {
        if result.hasAnyPersonalBest {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("New Personal Best!")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }

                HStack(spacing: 12) {
                    if result.isNewLongestDistance {
                        pbItem(icon: "figure.walk", label: "Distance", value: FormatUtils.formatDistance(result.currentDistance))
                    }
                    if result.isNewLongestDuration {
                        pbItem(icon: "clock", label: "Duration", value: FormatUtils.formatDuration(Int(result.currentDuration)))
                    }
                    if result.isNewFastestPace, let pace = result.currentPace {
                        pbItem(icon: "speedometer", label: "Pace", value: FormatUtils.formatPace(pace))
                    }
                    if result.isNewMostSteps {
                        pbItem(icon: "shoeprints.fill", label: "Steps", value: "\(result.currentSteps)")
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .scaleEffect(isShowing ? 1.0 : 0.8)
            .opacity(isShowing ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) { isShowing = true }
            }
        }
    }

    private func pbItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundColor(.orange)
            Text(value).font(.caption.bold())
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}
