// This file is excluded from compilation because it references types
// that don't exist in the actual codebase yet.
#if false
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

final class MockDIContainer: ServiceLocatorProtocol {
    private var services: [String: Any] = [:]
    private let lock = NSLock()

    init() {
        registerMockServices()
    }

    private func registerMockServices() {
        register(Auth.self) { MockAuth() as! Auth }
        register(Firestore.self) { MockFirestore() as! Firestore }
        register(Storage.self) { MockStorage() as! Storage }
        register(URLSession.self) { URLSession.shared }
    }

    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        services[key] = factory()
    }

    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }

        guard let service = services[key] as? T else {
            fatalError("Mock not registered for type: \(key)")
        }
        return service
    }

    func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        return services[key] as? T
    }
}

class MockAuth {
    var currentUser: MockUser?
}

class MockUser {
    var uid: String = "test-user-id"
    var email: String? = "test@example.com"
}

class MockFirestore {
    func collection(_ path: String) -> MockCollectionReference {
        MockCollectionReference(path: path)
    }
}

class MockCollectionReference {
    let path: String

    init(path: String) {
        self.path = path
    }

    func document(_ id: String) -> MockDocumentReference {
        MockDocumentReference(path: "\(path)/\(id)")
    }
}

class MockDocumentReference {
    let path: String

    init(path: String) {
        self.path = path
    }
}

class MockStorage {
    func reference(withPath path: String) -> MockStorageReference {
        MockStorageReference(path: path)
    }
}

class MockStorageReference {
    let path: String

    init(path: String) {
        self.path = path
    }
}

extension ViewModelProvider {
    static func createMock() -> ViewModelProvider {
        ServiceLocator.setLocator(MockDIContainer())
        return ViewModelProvider.shared
    }
}
#endif
