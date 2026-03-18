import SwiftUI

struct WeatherWidget: View {
    @StateObject private var viewModel = WeatherWidgetViewModel()

    var body: some View {
        if let weather = viewModel.currentWeather {
            HStack(spacing: 8) {
                Image(systemName: weather.icon)
                    .font(.title3)
                    .foregroundColor(weather.iconColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(weather.temperature)\u{00B0}")
                        .font(.subheadline.bold())
                    Text(weather.condition)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if weather.isRaining {
                    Image(systemName: "umbrella.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
        }
    }
}

// MARK: - Weather Widget ViewModel

@MainActor
class WeatherWidgetViewModel: ObservableObject {
    struct WeatherData {
        let temperature: Int
        let condition: String
        let icon: String
        let iconColor: Color
        let isRaining: Bool
    }

    @Published var currentWeather: WeatherData?

    init() {
        // Default placeholder - would use WeatherKit or OpenWeather API
        currentWeather = WeatherData(
            temperature: 12,
            condition: "Partly Cloudy",
            icon: "cloud.sun.fill",
            iconColor: .orange,
            isRaining: false
        )
    }

    func refresh() {
        // Future: fetch real weather data from WeatherKit
        // For now, keep the placeholder
    }
}

// MARK: - Weather Condition Presets

extension WeatherWidgetViewModel.WeatherData {
    static let sunny = WeatherWidgetViewModel.WeatherData(
        temperature: 22,
        condition: "Sunny",
        icon: "sun.max.fill",
        iconColor: .yellow,
        isRaining: false
    )

    static let rainy = WeatherWidgetViewModel.WeatherData(
        temperature: 8,
        condition: "Rain",
        icon: "cloud.rain.fill",
        iconColor: .gray,
        isRaining: true
    )

    static let cloudy = WeatherWidgetViewModel.WeatherData(
        temperature: 14,
        condition: "Cloudy",
        icon: "cloud.fill",
        iconColor: .gray,
        isRaining: false
    )

    static let snowy = WeatherWidgetViewModel.WeatherData(
        temperature: -2,
        condition: "Snow",
        icon: "cloud.snow.fill",
        iconColor: .cyan,
        isRaining: false
    )
}

#Preview {
    ZStack {
        Color.green.ignoresSafeArea()
        VStack {
            WeatherWidget()
            Spacer()
        }
        .padding(.top, 60)
    }
}
