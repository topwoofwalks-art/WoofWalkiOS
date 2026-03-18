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
    var dogPhotoURL: URL? = nil
    var routeAdherencePercent: Double? = nil
    var achievements: [WalkAchievement] = []

    // Brand colours matching Android CardDark / CardDarkEnd
    private let cardDark = Color(red: 13/255, green: 27/255, blue: 42/255)    // #0D1B2A
    private let cardDarkEnd = Color(red: 27/255, green: 40/255, blue: 56/255) // #1B2838
    private let statCellBg = Color(red: 26/255, green: 38/255, blue: 52/255)  // #1A2634

    var body: some View {
        VStack(spacing: 0) {
            // Top ~35%: Hero section (dog photo or map)
            heroSection
                .frame(height: heroHeight)
                .clipped()

            // Bottom ~65%: Stats area with paw watermark
            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [cardDark, cardDarkEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Paw print watermark texture
                pawWatermarkOverlay

                VStack(spacing: 12) {
                    // Route map thumbnail when dog photo is hero
                    if dogPhotoURL != nil, let mapImage = mapImage {
                        Image(uiImage: mapImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 12)
                    }

                    statsRow
                    personalBestsRow
                    routeAdherenceRow
                    achievementBadgesRow
                    charityRow

                    Spacer(minLength: 0)

                    brandingFooter
                }
                .padding(16)
            }
        }
        .background(cardDark)
        .cornerRadius(16)
        .shadow(radius: 4)
    }

    /// Dynamic hero height: 35% of the 4:5 ratio card (1350 * 0.35 = ~472)
    /// For preview we use a relative proportion
    private var heroHeight: CGFloat { 200 }

    // MARK: - Hero section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Background: dog photo or map
            if let dogPhotoURL = dogPhotoURL {
                AsyncImage(url: dogPhotoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        mapHeroFallback
                    case .empty:
                        // Loading placeholder
                        Rectangle()
                            .fill(cardDark)
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                    @unknown default:
                        mapHeroFallback
                    }
                }
            } else {
                mapHeroFallback
            }

            // Gradient overlay from transparent to dark for text legibility
            LinearGradient(
                colors: [
                    .clear,
                    (dogPhotoURL != nil ? Color.black.opacity(0.7) : cardDark)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)

            // Dog name(s) overlaid at bottom of hero
            HStack {
                Text(heroLabel)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 1, y: 1)
                    .lineLimit(1)
                Spacer()
                if streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(streakDays)")
                            .fontWeight(.bold)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.3)))
                    .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    private var heroLabel: String {
        let capitalised = dogNames.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        switch capitalised.count {
        case 0: return "Walk Completed"
        case 1: return capitalised[0]
        case 2: return "\(capitalised[0]) & \(capitalised[1])"
        default: return "\(capitalised[0]), \(capitalised[1]) + \(capitalised.count - 2) more"
        }
    }

    @ViewBuilder
    private var mapHeroFallback: some View {
        if let mapImage = mapImage {
            Image(uiImage: mapImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(
                    LinearGradient(colors: [cardDark, cardDarkEnd], startPoint: .top, endPoint: .bottom)
                )
                .overlay {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.15))
                }
        }
    }

    // MARK: - Paw watermark texture overlay

    private var pawWatermarkOverlay: some View {
        GeometryReader { geo in
            let cols = 5
            let rows = 4
            let cellW = geo.size.width / CGFloat(cols)
            let cellH = geo.size.height / CGFloat(rows)
            ForEach(0..<(cols * rows), id: \.self) { i in
                let col = i % cols
                let row = i / cols
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.04))
                    .rotationEffect(.degrees(Double((col + row) * 15) - 30))
                    .position(
                        x: CGFloat(col) * cellW + cellW / 2,
                        y: CGFloat(row) * cellH + cellH / 2
                    )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            shareStatColumn(value: FormatUtils.formatDistance(distance), label: "Distance")
            statDivider
            shareStatColumn(value: FormatUtils.formatDurationCompact(duration), label: "Duration")
            statDivider
            shareStatColumn(value: FormatUtils.formatPace(pace), label: "Pace")
            if steps > 0 {
                statDivider
                shareStatColumn(value: "\(steps)", label: "Steps")
            }
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(statCellBg))
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 40)
    }

    // MARK: - Route adherence

    @ViewBuilder
    private var routeAdherenceRow: some View {
        if let adherence = routeAdherencePercent, adherence > 0 {
            HStack {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .font(.caption)
                    .foregroundColor(.turquoise60)
                Text("Route adherence")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.0f%%", adherence))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.turquoise60)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(statCellBg))
        }
    }

    // MARK: - Achievement badges

    @ViewBuilder
    private var achievementBadgesRow: some View {
        if !achievements.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(achievements.prefix(4)) { achievement in
                        HStack(spacing: 4) {
                            Image(systemName: achievement.icon)
                                .font(.caption2)
                                .foregroundColor(achievement.color)
                            Text(achievement.title)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(achievement.color.opacity(0.15)))
                    }
                }
            }
        }
    }

    // MARK: - Personal bests

    @ViewBuilder
    private var personalBestsRow: some View {
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
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.yellow.opacity(0.15)))
                }
            }
        }
    }

    // MARK: - Charity

    @ViewBuilder
    private var charityRow: some View {
        if charityPoints > 0 {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                Text("\(charityPoints) charity points donated")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Branding footer

    private var brandingFooter: some View {
        HStack {
            Text(date, style: .date)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
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

    // MARK: - Helpers

    private func shareStatColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
