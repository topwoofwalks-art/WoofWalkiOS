import Foundation

@MainActor
class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var currentVersion: String

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    func checkForUpdate() async {
        print("[AppUpdateChecker] Current version: \(currentVersion)")

        // App Store lookup API
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=com.woofwalk.ios") else {
            latestVersion = currentVersion
            updateAvailable = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let version = first["version"] as? String {
                latestVersion = version
                updateAvailable = version.compare(currentVersion, options: .numeric) == .orderedDescending
            } else {
                // App not yet on App Store
                latestVersion = currentVersion
                updateAvailable = false
            }
        } catch {
            print("[AppUpdateChecker] Update check failed: \(error)")
            latestVersion = currentVersion
            updateAvailable = false
        }
    }
}
