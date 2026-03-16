# Dependency Injection System

iOS port of Android Hilt DI pattern using manual DI container.

## Architecture

### DIContainer
Core singleton container managing service lifecycle:
- Thread-safe registration/resolution
- Singleton & factory patterns
- Type-safe resolution

### Components

#### 1. DIContainer.swift
Main container with automatic registration:
- Firebase services (Auth, Firestore, Storage)
- Network services (URLSession, OSRM, Overpass, Directions)
- Data services (Database, DAOs)
- Location services (LocationService, CLLocationManager)
- Utility services (UserDataStore, ImageCompressor, NotificationHelper, etc.)
- All repositories

#### 2. Injected.swift
Property wrappers for injection:
```swift
@Injected var repository: UserRepository
@InjectedObject var locationService: LocationService
```

#### 3. ViewModelFactory.swift
Factory for creating ViewModels with dependencies:
```swift
let viewModel = ViewModelProvider.shared.makeMapViewModel()
```

#### 4. ServiceLocator.swift
Static accessors for common services:
```swift
let repo = ServiceLocator.userRepository
let location = ServiceLocator.locationService
```

#### 5. AppDependencies.swift
App-level configuration:
- Firebase emulator setup (DEBUG)
- Environment integration
- Dependency initialization

#### 6. MockContainer.swift
Testing support with mock services

## Usage Patterns

### In Views
```swift
struct MapView: View {
    @StateObject private var viewModel = ViewModelProvider.shared.makeMapViewModel()
    @Injected var locationService: LocationService

    var body: some View {
        // UI code
    }
}
```

### In ViewModels
```swift
class MapViewModel: ObservableObject {
    @Injected private var poiRepository: PoiRepository
    @Injected private var routeRepository: RouteRepository

    init() {
        // Dependencies auto-injected
    }
}
```

Or with explicit injection:
```swift
class MapViewModel: ObservableObject {
    private let poiRepository: PoiRepository
    private let routeRepository: RouteRepository

    init(
        poiRepository: PoiRepository,
        routeRepository: RouteRepository
    ) {
        self.poiRepository = poiRepository
        self.routeRepository = routeRepository
    }
}
```

### Environment Objects
```swift
@main
struct WoofWalkApp: App {
    init() {
        AppEnvironment.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .injectDependencies()
        }
    }
}
```

## Registered Dependencies

### Firebase
- Auth
- Firestore (with persistence, 10MB cache)
- Storage

### Network
- URLSession (10s connect, 15s read timeout)
- OsrmService
- OverpassService
- DirectionsService

### Data
- WoofWalkDatabase (singleton)
- All DAOs (via database)

### Location
- CLLocationManager (factory)
- LocationService (singleton)

### Utilities
- UserDataStore
- ImageCompressor
- NotificationHelper
- GeofenceManager
- StorageManager
- FcmManager

### Repositories
- UserRepository
- DogRepository
- WalkRepository
- WalkSessionRepository
- PoiRepository
- PoiCacheRepository
- RouteRepository
- DirectionsRepository
- PooBagDropRepository
- PublicDogRepository
- LostDogRepository
- FriendRepository
- ChatRepository
- FeedRepository
- EventRepository

## Android → iOS Mapping

| Android | iOS |
|---------|-----|
| @Inject constructor | init() with @Injected |
| @HiltViewModel | ViewModelProvider.makeXXX() |
| @Module @Provides | DIContainer.register() |
| @Singleton | singleton: true |
| @InstallIn(SingletonComponent::class) | DIContainer registration |
| Hilt entry points | ServiceLocator static properties |

## Testing

Use MockDIContainer for unit tests:
```swift
#if DEBUG
let mockContainer = MockDIContainer()
mockContainer.register(UserRepository.self) { MockUserRepository() }
ServiceLocator.setLocator(mockContainer)
#endif
```

## Configuration

### Debug Mode
- Firebase emulators (localhost:9099/8080/9199)
- Set USE_FIREBASE_EMULATOR=true

### Production
- Real Firebase services
- Optimized network timeouts

## Best Practices

1. Use @Injected for simple dependencies
2. Use ViewModelProvider for ViewModels
3. Use ServiceLocator for static access
4. Register singletons for stateful services
5. Register factories for lightweight/transient objects
6. Thread-safe by design (NSLock)
7. Reset container for testing: DIContainer.shared.reset()
