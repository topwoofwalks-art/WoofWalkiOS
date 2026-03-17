import SwiftUI

struct StreakCompletionCard: View {
    let streakDays: Int
    let freezeCount: Int

    @State private var displayedCount: Int = 0
    @State private var showMilestone = false

    private var milestoneLabel: String? {
        let thresholds = [365, 180, 90, 60, 30, 14, 7]
        for t in thresholds {
            if streakDays >= t { return "\(t)-Day Streak!" }
        }
        return nil
    }

    private var isMilestone: Bool {
        [7, 14, 30, 60, 90, 180, 365].contains(streakDays)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Fire emoji + animated count
            HStack(spacing: 8) {
                Text("\u{1F525}")
                    .font(.system(size: 36))

                Text("\(displayedCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .contentTransition(.numericText(countsDown: false))

                Text("days")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Milestone label
            if let label = milestoneLabel {
                Text(label)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .scaleEffect(showMilestone ? 1.0 : 0.5)
                    .opacity(showMilestone ? 1 : 0)
            }

            // Freeze count
            if freezeCount > 0 {
                HStack(spacing: 4) {
                    Text("\u{2744}\u{FE0F}")
                        .font(.caption)
                    Text("\(freezeCount) freeze\(freezeCount == 1 ? "" : "s") remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isMilestone
                      ? Color.orange.opacity(0.12)
                      : Color(.systemGray6))
        )
        .padding(.horizontal)
        .onAppear {
            animateCount()
        }
    }

    private func animateCount() {
        let totalDuration: Double = 0.8
        let steps = min(streakDays, 30)
        guard steps > 0 else { return }
        let interval = totalDuration / Double(steps)

        for i in 1...steps {
            let value = Int(Double(streakDays) * Double(i) / Double(steps))
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.05)) {
                    displayedCount = value
                }
                if i == steps {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) {
                        showMilestone = true
                    }
                }
            }
        }
    }
}
