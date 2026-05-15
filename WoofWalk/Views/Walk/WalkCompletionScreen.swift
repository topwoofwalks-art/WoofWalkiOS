import SwiftUI
import CoreLocation
import FirebaseAuth

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
    /// Optional planned-vs-actual comparison. When non-nil AND
    /// `hasPlannedRoute == true`, the recap renders a "Planned vs Actual"
    /// section with distance/duration/route-adherence/POI cards above the
    /// existing stats. Defaults to nil for back-compat — callers that
    /// don't have a planned route just don't pass it.
    let comparison: WalkComparison?
    /// Weather samples collected during the walk by
    /// `WalkTrackingService.weatherSamples`. Rendered as the recap card
    /// between the stats card and the charity card. Empty list = card
    /// not rendered (e.g. a walk that finished before the first sample
    /// landed, or pre-existing call sites that don't pass samples).
    let weatherSamples: [WeatherSample]
    /// Walker UID + display name + booking id for the optional Tip-walker
    /// action. When all three are non-nil/non-empty AND the current user
    /// is NOT the walker, a Tip CTA is rendered below the share row. Tap
    /// → presents `TipWalkerSheet`.
    let walkerUid: String?
    let walkerName: String?
    let bookingId: String?
    let onShare: () -> Void
    let onDone: () -> Void

    @State private var showConfetti = true
    @State private var revealStats = false
    @State private var displayedPoints: Int = 0
    @State private var showTipSheet: Bool = false
    @State private var tipSuccessMessage: String?

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
        comparison: WalkComparison? = nil,
        weatherSamples: [WeatherSample] = [],
        walkerUid: String? = nil,
        walkerName: String? = nil,
        bookingId: String? = nil,
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
        self.comparison = comparison
        self.weatherSamples = weatherSamples
        self.walkerUid = walkerUid
        self.walkerName = walkerName
        self.bookingId = bookingId
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

                    if let comp = comparison, comp.hasPlannedRoute {
                        plannedVsActualSection(comp)
                    }

                    statsCard

                    // Weather recap — temp range + condition timeline +
                    // one-line summary. Sits between the stats card and
                    // the remaining recap rows, mirroring Android
                    // `WalkCompletionScreen.kt`'s placement.
                    if !weatherSamples.isEmpty {
                        WeatherSummaryCard(weatherSamples: weatherSamples)
                    }

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
            comparison: comparison,
            personalBest: personalBest
        )
        .padding(.horizontal)
    }

    // MARK: - Planned vs Actual

    /// Four metric cards (distance, duration, route adherence %, POI
    /// visits) shown when the walk had a planned route. Mirrors Android's
    /// `WalkCompletionScreen.kt:318-392`.
    private func plannedVsActualSection(_ comp: WalkComparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planned vs Actual")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ComparisonMetricCard(
                    title: "Distance",
                    planned: String(format: "%.2f km", comp.plannedDistanceKm),
                    actual: String(format: "%.2f km", comp.actualDistanceKm),
                    diffPercent: comp.distanceDiffPercent,
                    direction: .lowerIsBetter
                )

                ComparisonMetricCard(
                    title: "Duration",
                    planned: "\(Int(comp.plannedDurationMin)) min",
                    actual: "\(Int(comp.actualDurationMin)) min",
                    diffPercent: comp.durationDiffPercent,
                    direction: .lowerIsBetter
                )

                ComparisonMetricCard(
                    title: "Route Adherence",
                    planned: "100%",
                    actual: String(format: "%.0f%%", comp.routeAdherencePercent),
                    // Adherence is reported as an absolute %, not a delta —
                    // the actual cell already tells the story so suppress
                    // the Δ column to avoid double-counting.
                    diffPercent: nil,
                    direction: .higherIsBetter
                )

                if comp.poisPlanned > 0 {
                    ComparisonMetricCard(
                        title: "Points of Interest",
                        planned: "\(comp.poisPlanned)",
                        actual: "\(comp.poisVisited)",
                        diffPercent: nil,
                        direction: .higherIsBetter
                    )
                }
            }
            .padding(.horizontal)
        }
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

            // Tip-walker CTA — only when the recap has booking context AND
            // the current viewer isn't the walker themselves (server-side
            // `processTip` enforces the same — clients can never tip
            // themselves — but we suppress the button so the UI doesn't
            // dangle a CTA that can't possibly succeed).
            if shouldShowTipButton {
                Button {
                    showTipSheet = true
                } label: {
                    Label("Tip your walker", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundColor(.turquoise60)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.turquoise60, lineWidth: 1.5)
                        )
                }
            }

            if let msg = tipSuccessMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundColor(.turquoise60)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
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
        .sheet(isPresented: $showTipSheet) {
            if let uid = walkerUid, let name = walkerName, let booking = bookingId {
                TipWalkerSheet(
                    walkerName: name,
                    walkerUid: uid,
                    bookingId: booking,
                    suggestedTip: suggestedTipPence,
                    onSuccess: { _ in
                        showTipSheet = false
                        let resolvedName = walkerName ?? "your walker"
                        withAnimation {
                            tipSuccessMessage = "Thanks! \(resolvedName) will see your tip."
                        }
                    },
                    onCancel: { showTipSheet = false }
                )
            }
        }
    }

    /// Show the tip CTA only when we have a non-empty walkerUid, booking
    /// id, and walker name AND the current Firebase Auth user is NOT the
    /// walker. Falls open (button hidden) when any field is missing.
    private var shouldShowTipButton: Bool {
        guard let uid = walkerUid, !uid.isEmpty,
              let _ = walkerName, !(walkerName ?? "").isEmpty,
              let bid = bookingId, !bid.isEmpty else { return false }
        let currentUid = Auth.auth().currentUser?.uid
        return currentUid != nil && currentUid != uid
    }

    /// Suggested tip in pence — 10% of the walk's pawpoint value as a
    /// rough proxy, floored at £2 (200p) so the default lands on a
    /// preset. Callers can replace this with a booking-price-derived
    /// value in a follow-up; matters less than offering a sane default.
    private var suggestedTipPence: Int {
        let tenPercent = pointsEarned * 10  // pointsEarned ~ tens, *10 ≈ pence
        return max(200, min(1000, tenPercent))
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
