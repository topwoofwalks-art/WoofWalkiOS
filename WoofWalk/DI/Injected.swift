import Foundation
import SwiftUI

@propertyWrapper
struct Injected<T> {
    private var dependency: T

    init() {
        self.dependency = DIContainer.shared.resolve(T.self)
    }

    init(_ type: T.Type) {
        self.dependency = DIContainer.shared.resolve(type)
    }

    var wrappedValue: T {
        get { dependency }
        mutating set { dependency = newValue }
    }

    var projectedValue: Injected<T> {
        get { self }
        mutating set { self = newValue }
    }
}

@propertyWrapper
struct InjectedObject<T: ObservableObject>: DynamicProperty {
    @ObservedObject private var dependency: T

    init() {
        self.dependency = DIContainer.shared.resolve(T.self)
    }

    init(_ type: T.Type) {
        self.dependency = DIContainer.shared.resolve(type)
    }

    var wrappedValue: T {
        get { dependency }
        mutating set { dependency = newValue }
    }

    var projectedValue: ObservedObject<T>.Wrapper {
        return $dependency
    }
}

extension View {
    func injectDependencies() -> some View {
        self
            .environmentObject(DIContainer.shared.resolve(UserRepository.self))
            .environmentObject(DIContainer.shared.resolve(DogRepository.self))
            .environmentObject(DIContainer.shared.resolve(WalkRepository.self))
            .environmentObject(DIContainer.shared.resolve(LocationService.self))
    }
}
