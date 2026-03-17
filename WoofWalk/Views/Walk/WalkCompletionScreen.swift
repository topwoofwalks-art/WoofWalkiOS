import SwiftUI

struct WalkCompletionScreen: View {
    let distance: Double
    let duration: Int
    let pace: Double
    let steps: Int
    let dogNames: [String]
    let pointsEarned: Int
    let personalBest: PersonalBestResult?
    let streakDays: Int
    let milestones: [DogMilestone]
    let mapImage: UIImage?
    let onShare: () -> Void
    let onDone: () -> Void

    @State private var showConfetti = true
    @State private var revealStats = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    completionHeader
                    pointsBadge
                    streakBadge
                    statsCard
                    milestonesList
                    actionButtons
                }
            }
            confettiOverlay
        }
    }

    // MARK: - Sub-views

    private var completionHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("Walk Complete!")
                .font(.largeTitle.bold())
            Text(dogNames.joined(separator: " & "))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    private var pointsBadge: some View {
        HStack {
            Image(systemName: "pawprint.fill")
                .foregroundColor(.turquoise60)
            Text("+\(pointsEarned) Paw Points")
                .font(.title3.bold())
                .foregroundColor(.turquoise60)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise90.opacity(0.3)))
    }

    @ViewBuilder
    private var streakBadge: some View {
        if streakDays > 0 {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(streakDays) day streak!")
                    .font(.headline)
            }
        }
    }

    private var statsCard: some View {
        WalkReportCardView(
            distance: distance,
            duration: duration,
            pace: pace,
            steps: steps,
            dogNames: dogNames,
            comparison: nil,
            personalBest: personalBest
        )
        .padding(.horizontal)
    }

    private var milestonesList: some View {
        ForEach(milestones) { milestone in
            HStack {
                Image(systemName: "trophy.fill").foregroundColor(.yellow)
                VStack(alignment: .leading) {
                    Text(milestone.title).font(.subheadline.bold())
                    Text("+\(milestone.pawPointsBonus) bonus points").font(.caption).foregroundColor(.turquoise60)
                }
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.1)))
            .padding(.horizontal)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onShare) {
                Label("Share Walk", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
            }

            Button(action: onDone) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.turquoise60)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var confettiOverlay: some View {
        if showConfetti {
            ConfettiEffect()
                .allowsHitTesting(false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { showConfetti = false }
                    }
                }
        }
    }
}
