import SwiftUI
import CoreLocation

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
        let precipitation: Double
        let windSpeed: Double
    }

    @Published var currentWeather: WeatherData?

    init() {
        // Show placeholder while loading
        currentWeather = WeatherData(
            temperature: 0,
            condition: "Loading...",
            icon: "cloud.fill",
            iconColor: .gray,
            isRaining: false,
            precipitation: 0,
            windSpeed: 0
        )
    }

    func refresh(latitude: Double, longitude: Double) {
        Task {
            do {
                let weather = try await fetchWeather(lat: latitude, lng: longitude)
                self.currentWeather = weather
            } catch {
                print("[WeatherWidget] Failed to fetch weather: \(error.localizedDescription)")
            }
        }
    }

    private func fetchWeather(lat: Double, lng: Double) async throws -> WeatherData {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lng)&current=temperature_2m,precipitation,rain,showers,weather_code,wind_speed_10m"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let current = json?["current"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        let temp = current["temperature_2m"] as? Double ?? 0
        let precip = current["precipitation"] as? Double ?? 0
        let rain = current["rain"] as? Double ?? 0
        let showers = current["showers"] as? Double ?? 0
        let weatherCode = current["weather_code"] as? Int ?? 0
        let windSpeed = current["wind_speed_10m"] as? Double ?? 0

        let totalRain = rain + showers + precip
        let isRaining = totalRain > 0.1

        let (condition, icon, iconColor) = Self.mapWeatherCode(weatherCode)

        return WeatherData(
            temperature: Int(temp),
            condition: condition,
            icon: icon,
            iconColor: iconColor,
            isRaining: isRaining,
            precipitation: totalRain,
            windSpeed: windSpeed
        )
    }

    private static func mapWeatherCode(_ code: Int) -> (String, String, Color) {
        switch code {
        case 0: return ("Clear", "sun.max.fill", .yellow)
        case 1: return ("Mostly Clear", "sun.min.fill", .yellow)
        case 2: return ("Partly Cloudy", "cloud.sun.fill", .orange)
        case 3: return ("Overcast", "cloud.fill", .gray)
        case 45, 48: return ("Fog", "cloud.fog.fill", .gray)
        case 51, 53, 55: return ("Drizzle", "cloud.drizzle.fill", .blue)
        case 56, 57: return ("Freezing Drizzle", "cloud.sleet.fill", .cyan)
        case 61: return ("Light Rain", "cloud.rain.fill", .blue)
        case 63: return ("Rain", "cloud.rain.fill", .blue)
        case 65: return ("Heavy Rain", "cloud.heavyrain.fill", .blue)
        case 66, 67: return ("Freezing Rain", "cloud.sleet.fill", .cyan)
        case 71, 73, 75: return ("Snow", "cloud.snow.fill", .cyan)
        case 77: return ("Snow Grains", "cloud.snow.fill", .cyan)
        case 80, 81, 82: return ("Showers", "cloud.rain.fill", .blue)
        case 85, 86: return ("Snow Showers", "cloud.snow.fill", .cyan)
        case 95: return ("Thunderstorm", "cloud.bolt.rain.fill", .purple)
        case 96, 99: return ("Hail Storm", "cloud.bolt.fill", .purple)
        default: return ("Unknown", "cloud.fill", .gray)
        }
    }
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
