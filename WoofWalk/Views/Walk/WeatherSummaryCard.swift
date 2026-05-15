import SwiftUI

/// One sampled weather reading collected during a walk. Lightweight on
/// purpose — we sample every ~10 min from open-meteo (the same service
/// `WeatherWidget` uses) and persist the array onto the walk doc on
/// `stopTracking()`. Mirrors Android `data/weather/WeatherSample.kt`.
struct WeatherSample: Codable, Hashable, Identifiable {
    /// Wall-clock seconds since epoch when the sample was taken.
    let timestamp: TimeInterval
    /// Air temperature in °C.
    let temperatureCelsius: Double
    /// Total precipitation (rain + showers) in mm at sample time. 0 = dry.
    let precipitationMm: Double
    /// Open-meteo weather code — drives the SF Symbol picker.
    let weatherCode: Int

    var id: TimeInterval { timestamp }

    /// True if measurable precipitation was falling at this sample.
    var isWet: Bool { precipitationMm > 0.1 }
}

/// Post-walk weather recap. Renders the temperature range across the
/// walk, an iconised condition timeline (sun → rain → clearing), and a
/// one-line summary line ("Cool but dry", "Wet half the walk", etc).
///
/// Sits between the stats card and the charity card on
/// `WalkCompletionScreen`. Mirrors Android `ui/walk/WeatherSummaryCard.kt`
/// in shape and tone — the iOS card is a recap, not the pre-walk
/// recommendation widget (which is `Views/Map/WeatherWidget.swift`).
struct WeatherSummaryCard: View {
    let weatherSamples: [WeatherSample]

    var body: some View {
        if weatherSamples.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: title + temp range
            HStack(spacing: 10) {
                Image(systemName: "thermometer.medium")
                    .font(.title3)
                    .foregroundColor(.orange)
                Text("Weather on this walk")
                    .font(.subheadline.bold())
                Spacer()
                Text(tempRangeLabel)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }

            // Condition timeline — one icon per sample, smaller for >6 samples
            timeline

            // Summary line — "Cool but dry", "Warm with showers", etc.
            Text(summaryLine)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Timeline

    private var timeline: some View {
        let icons = condensedTimelineIcons
        return HStack(spacing: 6) {
            ForEach(Array(icons.enumerated()), id: \.offset) { _, icon in
                Image(systemName: icon.symbol)
                    .font(.system(size: 18))
                    .foregroundColor(icon.color)
                    .frame(width: 22, height: 22)
            }
            Spacer()
        }
    }

    /// Up to ~8 evenly-spaced icons across the walk so even a 10-sample
    /// walk renders cleanly without overflowing a 4-inch screen.
    private var condensedTimelineIcons: [(symbol: String, color: Color)] {
        let maxIcons = 8
        let samples = weatherSamples
        guard !samples.isEmpty else { return [] }

        let pickedIndices: [Int]
        if samples.count <= maxIcons {
            pickedIndices = Array(0..<samples.count)
        } else {
            // Even spacing including first + last
            pickedIndices = (0..<maxIcons).map { i in
                let frac = Double(i) / Double(maxIcons - 1)
                return min(samples.count - 1, Int((Double(samples.count - 1) * frac).rounded()))
            }
        }

        return pickedIndices.map { idx in iconFor(code: samples[idx].weatherCode) }
    }

    private func iconFor(code: Int) -> (symbol: String, color: Color) {
        switch code {
        case 0: return ("sun.max.fill", .yellow)
        case 1: return ("sun.min.fill", .yellow)
        case 2: return ("cloud.sun.fill", .orange)
        case 3: return ("cloud.fill", .gray)
        case 45, 48: return ("cloud.fog.fill", .gray)
        case 51, 53, 55: return ("cloud.drizzle.fill", .blue)
        case 56, 57: return ("cloud.sleet.fill", .cyan)
        case 61: return ("cloud.rain.fill", .blue)
        case 63: return ("cloud.rain.fill", .blue)
        case 65: return ("cloud.heavyrain.fill", .blue)
        case 66, 67: return ("cloud.sleet.fill", .cyan)
        case 71, 73, 75, 77: return ("cloud.snow.fill", .cyan)
        case 80, 81, 82: return ("cloud.rain.fill", .blue)
        case 85, 86: return ("cloud.snow.fill", .cyan)
        case 95: return ("cloud.bolt.rain.fill", .purple)
        case 96, 99: return ("cloud.bolt.fill", .purple)
        default: return ("cloud.fill", .gray)
        }
    }

    // MARK: - Labels

    private var tempRangeLabel: String {
        let temps = weatherSamples.map { $0.temperatureCelsius }
        guard let lo = temps.min(), let hi = temps.max() else { return "" }
        if abs(hi - lo) < 0.5 {
            return String(format: "%d\u{00B0}C", Int(lo.rounded()))
        }
        return String(format: "%d\u{2013}%d\u{00B0}C", Int(lo.rounded()), Int(hi.rounded()))
    }

    /// One-liner summary that drives the "Cool but dry" voice. Picks the
    /// warmth bucket and the wetness bucket independently, then joins.
    private var summaryLine: String {
        let temps = weatherSamples.map { $0.temperatureCelsius }
        let avgTemp = temps.reduce(0, +) / Double(max(temps.count, 1))
        let warmth: String
        switch avgTemp {
        case ..<0: warmth = "Freezing"
        case 0..<8: warmth = "Cold"
        case 8..<14: warmth = "Cool"
        case 14..<20: warmth = "Mild"
        case 20..<26: warmth = "Warm"
        default: warmth = "Hot"
        }

        let wetSamples = weatherSamples.filter { $0.isWet }.count
        let totalSamples = weatherSamples.count
        let wetFrac = Double(wetSamples) / Double(max(totalSamples, 1))

        let condition: String
        switch wetFrac {
        case 0: condition = "and dry"
        case 0..<0.25:
            // A short shower somewhere
            if let firstWet = weatherSamples.first(where: { $0.isWet }),
               let lastWet = weatherSamples.last(where: { $0.isWet }),
               firstWet.timestamp == lastWet.timestamp {
                condition = "with a brief shower"
            } else {
                condition = "with passing showers"
            }
        case 0.25..<0.6: condition = "with showers"
        case 0.6..<1.0: condition = "and wet most of the way"
        default: condition = "and wet throughout"
        }

        return "\(warmth) \(condition)."
    }
}
