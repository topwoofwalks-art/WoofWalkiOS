import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var settings: UserSettings

    private let userDefaultsKey = "userSettings"
    private var cancellables = Set<AnyCancellable>()

    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = UserSettings()
        }

        $settings
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.saveSettings(settings)
            }
            .store(in: &cancellables)
    }

    private func saveSettings(_ settings: UserSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func updateDistanceUnit(_ unit: DistanceUnit) {
        settings.distanceUnit = unit
    }

    func updateSpeedUnit(_ unit: SpeedUnit) {
        settings.speedUnit = unit
    }

    func updateTheme(_ theme: ThemeMode) {
        settings.theme = theme
    }

    func updateMapStyle(_ style: MapStyleType) {
        settings.mapStyle = style
    }

    func updateShowTraffic(_ show: Bool) {
        settings.showTraffic = show
    }

    func updateDefaultWalkDistance(_ distance: Double) {
        settings.defaultWalkDistance = distance
    }

    func updateAutoPauseSensitivity(_ sensitivity: AutoPauseSensitivity) {
        settings.autoPauseSensitivity = sensitivity
    }

    func updateBackgroundTracking(_ enabled: Bool) {
        settings.backgroundTracking = enabled
    }

    func updateNotificationsEnabled(_ enabled: Bool) {
        settings.notificationsEnabled = enabled
    }

    func updateHazardAlertsEnabled(_ enabled: Bool) {
        settings.hazardAlertsEnabled = enabled
    }

    func updateCommunityAlertsEnabled(_ enabled: Bool) {
        settings.communityAlertsEnabled = enabled
    }

    func updateWalkRemindersEnabled(_ enabled: Bool) {
        settings.walkRemindersEnabled = enabled
    }

    func updateProfileVisible(_ visible: Bool) {
        settings.profileVisible = visible
    }

    func updateLocationSharingEnabled(_ enabled: Bool) {
        settings.locationSharingEnabled = enabled
    }

    func updateAlertRadius(_ meters: Int) {
        settings.alertRadiusMeters = meters
    }

    func updateSoundEnabled(_ enabled: Bool) {
        settings.soundEnabled = enabled
    }

    func updateVibrationEnabled(_ enabled: Bool) {
        settings.vibrationEnabled = enabled
    }

    func updateHeadsUpEnabled(_ enabled: Bool) {
        settings.headsUpEnabled = enabled
    }

    func updateQuietHoursEnabled(_ enabled: Bool) {
        settings.quietHoursEnabled = enabled
    }

    func updateQuietHoursStart(_ hour: Int) {
        settings.quietHoursStart = hour
    }

    func updateQuietHoursEnd(_ hour: Int) {
        settings.quietHoursEnd = hour
    }

    func toggleAlertType(_ type: String) {
        if settings.enabledAlertTypes.contains(type) {
            settings.enabledAlertTypes.remove(type)
        } else {
            settings.enabledAlertTypes.insert(type)
        }
    }

    func resetToDefaults() {
        settings = UserSettings()
    }

    func clearCache() {
        URLCache.shared.removeAllCachedResponses()
    }

    func exportData(completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try JSONEncoder().encode(self.settings)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("woofwalk_data_\(Date().timeIntervalSince1970).json")
                try data.write(to: tempURL)

                DispatchQueue.main.async {
                    completion(.success(tempURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
