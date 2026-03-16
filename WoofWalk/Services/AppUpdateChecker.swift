import Foundation

@MainActor
class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published var updateAvailable = false
    @Published var latestVersion = ""

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    func checkForUpdate() async {
        // App Store lookup API would go here
        // For now, this is a placeholder
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=com.woofwalk.ios") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let version = first["version"] as? String {
                latestVersion = version
                updateAvailable = version.compare(currentVersion, options: .numeric) == .orderedDescending
            }
        } catch {
            print("Update check failed: \(error)")
        }
    }
}
