import Foundation

// MARK: - AppMode

enum AppMode: String, CaseIterable, Identifiable {
    case public_ = "Public"
    case client = "Client"
    case business = "Business"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .public_:
            return "Browse walks and discover places"
        case .client:
            return "Book dog walking and pet services"
        case .business:
            return "Manage your business on the go"
        }
    }
}

// MARK: - AppModeManager

@MainActor
final class AppModeManager: ObservableObject {

    static let shared = AppModeManager()

    @Published var currentMode: AppMode = .public_

    private static let userDefaultsKey = "selectedAppMode"

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let mode = AppMode(rawValue: stored) {
            currentMode = mode
        }
    }

    func switchMode(_ mode: AppMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.userDefaultsKey)
    }
}
