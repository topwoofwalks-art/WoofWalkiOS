import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct AppDependencies {
    let container: DIContainer

    init(container: DIContainer = .shared) {
        self.container = container
    }

    func configure() {
        configureFirebase()
        configureDependencies()
    }

    private func configureFirebase() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATOR"] == "true" {
            let auth = Auth.auth()
            auth.useEmulator(withHost: "localhost", port: 9099)

            let db = Firestore.firestore()
            db.useEmulator(withHost: "localhost", port: 8080)

            let storage = Storage.storage()
            storage.useEmulator(withHost: "localhost", port: 9199)
        }
        #endif
    }

    private func configureDependencies() {
    }
}

final class AppEnvironment {
    static let shared = AppEnvironment()

    let dependencies: AppDependencies
    let viewModelProvider: ViewModelProvider

    private init() {
        self.dependencies = AppDependencies()
        self.viewModelProvider = ViewModelProvider.shared
        dependencies.configure()
    }

    static func configure() {
        _ = shared
    }
}

struct DependencyInjectionKey: EnvironmentKey {
    static let defaultValue: DIContainer = .shared
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DependencyInjectionKey.self] }
        set { self[DependencyInjectionKey.self] = newValue }
    }
}

extension View {
    func withDependencies(_ container: DIContainer = .shared) -> some View {
        self.environment(\.diContainer, container)
    }
}
