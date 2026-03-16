// This file is a reference example for DI integration patterns.
// It is excluded from compilation because it references illustrative
// types/methods that don't exist in the actual codebase.
#if false
import SwiftUI
import FirebaseCore

@main
struct WoofWalkApp_DI_Example: App {
    init() {
        FirebaseApp.configure()
        AppEnvironment.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .injectDependencies()
        }
    }
}

struct ExampleMapView: View {
    @StateObject private var viewModel = ViewModelProvider.shared.makeMapViewModel()
    @Injected var locationService: LocationService

    var body: some View {
        VStack {
            Text("Map View")
            Button("Start Tracking") {
                Task {
                    await locationService.startUpdatingLocation()
                }
            }
        }
    }
}

class ExampleViewModel: ObservableObject {
    @Injected private var userRepository: UserRepository
    @Injected private var dogRepository: DogRepository
    @Injected private var walkRepository: WalkRepository

    @Published var user: User?
    @Published var dogs: [Dog] = []
    @Published var walks: [Walk] = []

    func loadData() async {
        do {
            async let userTask = userRepository.fetchCurrentUser()
            async let dogsTask = dogRepository.fetchDogs()
            async let walksTask = walkRepository.fetchWalks()

            self.user = try await userTask
            self.dogs = try await dogsTask
            self.walks = try await walksTask
        } catch {
            print("Error loading data: \(error)")
        }
    }
}

class ManualConstructorViewModel: ObservableObject {
    private let userRepository: UserRepository
    private let locationService: LocationService

    init(
        userRepository: UserRepository,
        locationService: LocationService
    ) {
        self.userRepository = userRepository
        self.locationService = locationService
    }

    static func create() -> ManualConstructorViewModel {
        ManualConstructorViewModel(
            userRepository: DIContainer.shared.resolve(),
            locationService: DIContainer.shared.resolve()
        )
    }
}

struct ExampleViewWithEnvironment: View {
    @EnvironmentObject var userRepository: UserRepository
    @EnvironmentObject var locationService: LocationService

    var body: some View {
        Text("Using Environment Objects")
    }
}

struct ExampleServiceLocatorUsage: View {
    var body: some View {
        Button("Get User") {
            Task {
                let repo = ServiceLocator.userRepository
                let user = try? await repo.fetchCurrentUser()
                print("User: \(user?.displayName ?? "Unknown")")
            }
        }
    }
}

#if DEBUG
struct ExampleTestingSetup {
    static func setupMocks() {
        let mockContainer = MockDIContainer()

        mockContainer.register(UserRepository.self) {
            MockUserRepository()
        }

        ServiceLocator.setLocator(mockContainer)
    }
}

class MockUserRepository: UserRepository {
    override func fetchCurrentUser() async throws -> User? {
        return User(
            id: "test-id",
            email: "test@example.com",
            displayName: "Test User",
            photoURL: nil
        )
    }
}

struct ExampleView_Previews: PreviewProvider {
    static var previews: some View {
        let _ = ExampleTestingSetup.setupMocks()

        ExampleMapView()
            .injectDependencies()
    }
}
#endif

struct DirectResolutionExample {
    func example() {
        let container = DIContainer.shared

        let auth = container.resolve(Auth.self)

        let userRepo = container.resolve(UserRepository.self)

        let locationService: LocationService = container.resolve()

        if let optionalService = container.resolveOptional(SomeOptionalService.self) {
            print("Service exists: \(optionalService)")
        }
    }
}

final class CustomServiceRegistration {
    static func registerCustomServices() {
        DIContainer.shared.register(MyCustomService.self, singleton: true) {
            MyCustomService(dependency1: DIContainer.shared.resolve())
        }
    }
}

class MyCustomService {
    private let dependency1: UserRepository

    init(dependency1: UserRepository) {
        self.dependency1 = dependency1
    }
}

class SomeOptionalService {}

extension ViewModelProvider {
    func makeCustomViewModel() -> CustomViewModel {
        CustomViewModel(
            customService: container.resolve(),
            userRepository: container.resolve()
        )
    }
}

class CustomViewModel: ObservableObject {
    private let customService: MyCustomService
    private let userRepository: UserRepository

    init(customService: MyCustomService, userRepository: UserRepository) {
        self.customService = customService
        self.userRepository = userRepository
    }
}
#endif
