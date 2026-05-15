import SwiftUI
import CoreLocation

struct WalkCompletionScreen: View {
    let distance: Double
    let duration: Int
    let pace: Double
    let steps: Int
    let dogNames: [String]
    let pointsEarned: Int
    let personalBest: PersonalBestResult?
    let streakDays: Int
    let freezeCount: Int
    let milestones: [DogMilestone]
    let achievements: [WalkAchievement]
    let trackPoints: [CLLocationCoordinate2D]
    let mapImage: UIImage?
    /// Walk-for-Charity contribution from this walk. 0 when charity
    /// mode wasn't enabled or no charity was selected. Surfaced via a
    /// dedicated card on the recap so users see the impact of every
    /// walk they take with charity mode on.
    let charityPoints: Int64
    let charityName: String
    let onShare: () -> Void
    let onDone: () -> Void

    @State private var showConfetti = true
    @State private var revealStats = false
    @State private var displayedPoints: Int = 0

    init(
        distance: Double,
        duration: Int,
        pace: Double,
        steps: Int,
        dogNames: [String],
        pointsEarned: Int,
        personalBest: PersonalBestResult?,
        streakDays: Int,
        freezeCount: Int = 0,
        milestones: [DogMilestone],
        achievements: [WalkAchievement] = [],
        trackPoints: [CLLocationCoordinate2D] = [],
        mapImage: UIImage?,
        charityPoints: Int64 = 0,
        charityName: String = "",
        onShare: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.distance = distance
        self.duration = duration
        self.pace = pace
        self.steps = steps
        self.dogNames = dogNames
        self.pointsEarned = pointsEarned
        self.personalBest = personalBest
        self.streakDays = streakDays
        self.freezeCount = freezeCount
        self.milestones = milestones
        self.achievements = achievements
        self.trackPoints = trackPoints
        self.mapImage = mapImage
        self.charityPoints = charityPoints
        self.charityName = charityName
        self.onShare = onShare
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    completionHeader

                    if !trackPoints.isEmpty {
                        CompletionMapSection(trackPoints: trackPoints)
                    }

                    animatedPointsBadge

                    if streakDays > 0 {
                        StreakCompletionCard(
                            streakDays: streakDays,
                            freezeCount: freezeCount
                        )
                    }

                    if !achievements.isEmpty {
                        achievementsSection
                    }

                    if charityPoints > 0 {
                        charityCard
                    }

                    statsCard
                    milestonesList
                    actionButtons
                }
            }
            confettiOverlay
        }
        .onAppear {
            animatePoints()
        }
    }

    private var charityCard: some View {
        HStack(spacing: 14) {
            Text("💚")
                .font(.system(size: 36))
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: String(localized: "walk_charity_points_format"), charityPoints))
                    .font(.headline)
                if !charityName.isEmpty {
                    Text(String(format: String(localized: "walk_charity_for_charity_format"), charityName))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(String(localized: "walk_charity_for_charity_generic"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Sub-views

    private var completionHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text(String(localized: "walk_complete_title"))
                .font(.largeTitle.bold())
            Text(dogNames.joined(separator: " & "))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    private var animatedPointsBadge: some View {
        HStack {
            Image(systemName: "pawprint.fill")
                .foregroundColor(.turquoise60)
            Text(String(format: String(localized: "walk_paw_points_format"), Int64(displayedPoints)))
                .font(.title3.bold())
                .foregroundColor(.turquoise60)
                .contentTransition(.numericText(countsDown: false))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise90.opacity(0.3)))
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "walk_achievements_header"))
                .font(.headline)
                .padding(.horizontal)

            ForEach(Array(achievements.enumerated()), id: \.element.id) { index, achievement in
                WalkAchievementCard(achievement: achievement)
                    .padding(.horizontal)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.6)
                            .delay(Double(index) * 0.15),
                        value: achievements.count
                    )
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
                    Text(String(format: String(localized: "walk_milestone_bonus_format"), Int64(milestone.pawPointsBonus))).font(.caption).foregroundColor(.turquoise60)
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
                Label(String(localized: "walk_share_button"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.turquoise60))
            }

            Button(action: onDone) {
                Text(String(localized: "walk_done_button"))
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

    // MARK: - Animation

    private func animatePoints() {
        let totalDuration: Double = 0.8
        let steps = min(pointsEarned, 40)
        guard steps > 0 else {
            displayedPoints = pointsEarned
            return
        }
        let interval = totalDuration / Double(steps)

        for i in 1...steps {
            let value = Int(Double(pointsEarned) * Double(i) / Double(steps))
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.05)) {
                    displayedPoints = value
                }
            }
        }
    }
}
