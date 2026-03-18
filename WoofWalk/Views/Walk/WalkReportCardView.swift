import SwiftUI

// MARK: - Dog Mood

enum DogMood: String, CaseIterable, Identifiable {
    case happy = "happy"
    case calm = "calm"
    case tired = "tired"
    case excited = "excited"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .happy: return "\u{1F436}"    // dog face
        case .calm: return "\u{1F60C}"     // relieved / calm
        case .tired: return "\u{1F634}"    // sleeping
        case .excited: return "\u{1F929}"  // star-struck
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

// MARK: - Report Card View

struct WalkReportCardView: View {
    let distance: Double
    let duration: Int
    let pace: Double
    let steps: Int
    let dogNames: [String]
    let comparison: WalkComparison?
    let personalBest: PersonalBestResult?

    @State private var selectedMood: DogMood? = nil
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Walk Report")
                        .font(.title2.bold())
                    Text(dogNames.joined(separator: " & "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "pawprint.fill")
                    .font(.title)
                    .foregroundColor(.turquoise60)
            }

            Divider()

            // Main stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                reportStat(icon: "figure.walk", label: "Distance", value: FormatUtils.formatDistance(distance))
                reportStat(icon: "clock", label: "Duration", value: FormatUtils.formatDuration(duration))
                reportStat(icon: "speedometer", label: "Avg Pace", value: FormatUtils.formatPace(pace))
                if steps > 0 { reportStat(icon: "shoeprints.fill", label: "Steps", value: "\(steps)") }
            }

            // Route comparison
            if let comp = comparison, comp.hasPlannedRoute {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Route Comparison").font(.headline)
                    HStack {
                        Text("Route adherence").font(.caption)
                        Spacer()
                        Text(String(format: "%.0f%%", comp.routeAdherencePercent)).font(.caption.bold())
                    }
                    ProgressView(value: comp.routeAdherencePercent / 100.0)
                        .tint(.turquoise60)
                }
            }

            // Personal best
            if let pb = personalBest {
                PersonalBestBanner(result: pb)
            }

            // Dog mood selector
            Divider()
            dogMoodSelector

            // Share button
            Divider()
            shareButton
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 2))
    }

    // MARK: - Dog mood selector

    private var dogMoodSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How was your dog?")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 12) {
                ForEach(DogMood.allCases) { mood in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedMood = mood
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.system(size: selectedMood == mood ? 32 : 26))
                            Text(mood.label)
                                .font(.caption2)
                                .foregroundColor(selectedMood == mood ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedMood == mood ? Color.turquoise60.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedMood == mood ? Color.turquoise60 : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Share button

    private var shareButton: some View {
        Button(action: {
            shareReportCard()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Share Report Card")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.turquoise60))
        }
    }

    // MARK: - Share action

    @MainActor private func shareReportCard() {
        // Build a shareable version of the report card (without interactive elements)
        let shareView = reportCardShareContent
        let image = shareView.renderToImage(size: ShareCardSize.socialMedia)

        // Present UIActivityViewController
        let dogLine = dogNames.isEmpty ? "" : " with \(dogNames.joined(separator: " & "))"
        let moodLine = selectedMood.map { " \($0.emoji) Mood: \($0.label)" } ?? ""
        let text = "Walk Report\(dogLine) - \(FormatUtils.formatDistance(distance)) in \(FormatUtils.formatDuration(duration))\(moodLine) \u{1F43E} #WoofWalk\nhttps://woofwalk.app"

        ShareService.shared.shareImage(image, text: text)
    }

    /// A non-interactive version of the report card for rendering to image
    private var reportCardShareContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Walk Report")
                        .font(.title.bold())
                    Text(dogNames.joined(separator: " & "))
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.turquoise60)
            }

            Divider()

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                reportStatLarge(icon: "figure.walk", label: "Distance", value: FormatUtils.formatDistance(distance))
                reportStatLarge(icon: "clock", label: "Duration", value: FormatUtils.formatDuration(duration))
                reportStatLarge(icon: "speedometer", label: "Avg Pace", value: FormatUtils.formatPace(pace))
                if steps > 0 {
                    reportStatLarge(icon: "shoeprints.fill", label: "Steps", value: "\(steps)")
                }
            }

            // Route comparison
            if let comp = comparison, comp.hasPlannedRoute {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Route Comparison").font(.title3.bold())
                    HStack {
                        Text("Route adherence").font(.subheadline)
                        Spacer()
                        Text(String(format: "%.0f%%", comp.routeAdherencePercent))
                            .font(.subheadline.bold())
                    }
                    ProgressView(value: comp.routeAdherencePercent / 100.0)
                        .tint(.turquoise60)
                }
            }

            // Mood
            if let mood = selectedMood {
                HStack(spacing: 8) {
                    Text(mood.emoji)
                        .font(.title)
                    Text("Mood: \(mood.label)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            // Branding
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "pawprint.fill")
                        .foregroundColor(.turquoise60)
                    Text("WoofWalk")
                        .fontWeight(.bold)
                        .foregroundColor(.turquoise60)
                }
                .font(.subheadline)
            }
        }
        .padding(40)
        .background(Color(.systemBackground))
    }

    // MARK: - Stat cells

    private func reportStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.turquoise60)
                .frame(width: 28)
            VStack(alignment: .leading) {
                Text(value).font(.headline)
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reportStatLarge(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.turquoise60)
                .frame(width: 36)
            VStack(alignment: .leading) {
                Text(value).font(.title2.bold())
                Text(label).font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
