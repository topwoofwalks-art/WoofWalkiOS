import Foundation
import Combine
import FirebaseAuth
import FirebaseFunctions

@MainActor
class SettingsViewModel: ObservableObject {
    private lazy var functions = Functions.functions(region: "europe-west2")

    enum ExportError: LocalizedError {
        case notSignedIn
        case malformedResponse
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You must be signed in to export your data."
            case .malformedResponse:
                return "Server returned an unexpected response. Please try again."
            case .writeFailed(let detail):
                return "Could not save export file: \(detail)"
            }
        }
    }

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

    // GDPR Article 20 — wired to the same `exportUserData` CF as
    // `DataManagementView`. The previous implementation encoded only
    // local `UserSettings` to disk, leaving the user's actual Firestore
    // data (dogs, posts, bookings, friendships, ...) inaccessible.
    func exportData(completion: @escaping (Result<URL, Error>) -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion(.failure(ExportError.notSignedIn))
            return
        }

        functions
            .httpsCallable("exportUserData")
            .call([:]) { result, error in
                Task { @MainActor in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    guard let data = result?.data as? [String: Any] else {
                        completion(.failure(ExportError.malformedResponse))
                        return
                    }

                    if let downloadUrlString = data["downloadUrl"] as? String,
                       let downloadUrl = URL(string: downloadUrlString) {
                        URLSession.shared.downloadTask(with: downloadUrl) { tempLocation, _, downloadError in
                            Task { @MainActor in
                                if let downloadError = downloadError {
                                    completion(.failure(downloadError))
                                    return
                                }
                                guard let tempLocation = tempLocation else {
                                    completion(.failure(ExportError.malformedResponse))
                                    return
                                }
                                let dest = FileManager.default.temporaryDirectory
                                    .appendingPathComponent("woofwalk_data_export_\(Int(Date().timeIntervalSince1970)).json")
                                try? FileManager.default.removeItem(at: dest)
                                do {
                                    try FileManager.default.moveItem(at: tempLocation, to: dest)
                                    completion(.success(dest))
                                } catch {
                                    completion(.failure(ExportError.writeFailed(error.localizedDescription)))
                                }
                            }
                        }.resume()
                        return
                    }

                    guard let bundle = data["bundle"] else {
                        completion(.failure(ExportError.malformedResponse))
                        return
                    }

                    do {
                        let json = try JSONSerialization.data(
                            withJSONObject: bundle,
                            options: [.prettyPrinted, .sortedKeys]
                        )
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("woofwalk_data_export_\(Int(Date().timeIntervalSince1970)).json")
                        try json.write(to: tempURL, options: .atomic)
                        completion(.success(tempURL))
                    } catch {
                        completion(.failure(ExportError.writeFailed(error.localizedDescription)))
                    }
                }
        }
    }
}
