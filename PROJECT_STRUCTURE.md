# WoofWalk iOS Project Structure

## Directory Overview

```
WoofWalkiOS/
├── WoofWalk.xcodeproj/           # Xcode project configuration
│   └── project.pbxproj            # Project settings and file references
│
├── WoofWalk/                      # Main application source
│   ├── WoofWalkApp.swift         # App entry point
│   ├── ContentView.swift         # Main content view
│   ├── Info.plist                # App configuration and permissions
│   │
│   ├── Models/                   # Domain models and data structures
│   │   ├── User.swift
│   │   ├── Dog.swift
│   │   ├── Walk.swift
│   │   ├── Location.swift
│   │   ├── POI.swift
│   │   ├── Post.swift
│   │   └── Comment.swift
│   │
│   ├── Views/                    # SwiftUI views and screens
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   ├── RegisterView.swift
│   │   │   └── OnboardingView.swift
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── MapView.swift
│   │   │   └── WalkCardView.swift
│   │   ├── Walk/
│   │   │   ├── WalkTrackingView.swift
│   │   │   ├── WalkHistoryView.swift
│   │   │   ├── WalkDetailView.swift
│   │   │   └── RoutePreviewView.swift
│   │   ├── Social/
│   │   │   ├── FeedView.swift
│   │   │   ├── PostDetailView.swift
│   │   │   ├── ProfileView.swift
│   │   │   └── FollowersView.swift
│   │   ├── Dogs/
│   │   │   ├── DogListView.swift
│   │   │   ├── DogDetailView.swift
│   │   │   └── AddDogView.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── ProfileSettingsView.swift
│   │       └── NotificationSettingsView.swift
│   │
│   ├── ViewModels/               # MVVM view models
│   │   ├── AuthViewModel.swift
│   │   ├── HomeViewModel.swift
│   │   ├── WalkViewModel.swift
│   │   ├── SocialViewModel.swift
│   │   ├── DogViewModel.swift
│   │   └── SettingsViewModel.swift
│   │
│   ├── Services/                 # Business logic services
│   │   ├── AuthService.swift
│   │   ├── LocationService.swift
│   │   ├── WalkTrackingService.swift
│   │   ├── MapService.swift
│   │   ├── NetworkService.swift
│   │   ├── NotificationService.swift
│   │   ├── ImageService.swift
│   │   └── RoutingService.swift
│   │
│   ├── Repositories/             # Data access layer
│   │   ├── UserRepository.swift
│   │   ├── DogRepository.swift
│   │   ├── WalkRepository.swift
│   │   ├── POIRepository.swift
│   │   ├── PostRepository.swift
│   │   └── CommentRepository.swift
│   │
│   ├── Database/                 # Local persistence
│   │   ├── CoreDataStack.swift
│   │   ├── WoofWalk.xcdatamodeld
│   │   ├── LocalWalk.swift
│   │   └── CacheManager.swift
│   │
│   ├── Utils/                    # Helpers and extensions
│   │   ├── Constants.swift
│   │   ├── Extensions.swift
│   │   ├── LocationManager.swift
│   │   ├── Logger.swift
│   │   └── Validators.swift
│   │
│   └── Resources/                # Assets and resources
│       ├── Assets.xcassets       # Images, colors, icons
│       └── Preview Content/      # Preview assets
│
├── WoofWalkTests/                # Unit tests
│   ├── ModelTests/
│   ├── ViewModelTests/
│   ├── ServiceTests/
│   └── RepositoryTests/
│
├── Podfile                       # CocoaPods dependencies
├── Podfile.lock                  # Locked dependency versions
├── .gitignore                    # Git ignore rules
├── README.md                     # Project documentation
├── SETUP_CHECKLIST.md           # Setup instructions
├── BUILD_CONFIGURATION.md       # Build and configuration guide
└── PROJECT_STRUCTURE.md         # This file
```

## Architecture Pattern: MVVM

### Models (Domain Layer)
- Pure data structures
- Business logic and validation
- Codable for serialization
- Equatable and Hashable

### Views (Presentation Layer)
- SwiftUI views
- User interface components
- Navigation and routing
- Data display only

### ViewModels (Presentation Logic)
- ObservableObject classes
- Published properties for UI binding
- User interaction handlers
- State management
- Coordinates with Services

### Services (Business Logic)
- Reusable business logic
- Network calls
- Location tracking
- Firebase operations
- No UI dependencies

### Repositories (Data Access)
- Abstraction over data sources
- Firebase Firestore integration
- Local database operations
- Caching strategies
- Data transformation

## Data Flow

```
View -> ViewModel -> Service -> Repository -> Firebase/Database
                                           |
                                           v
View <- ViewModel <- Service <- Repository <- Firebase/Database
```

## Key Features by Layer

### Models
- `User`: User profile and authentication data
- `Dog`: Dog profiles with breed, age, photos
- `Walk`: Walk session data with route and stats
- `Location`: GPS coordinates and timestamps
- `POI`: Points of interest with categories
- `Post`: Social feed posts with media
- `Comment`: User comments on posts

### Views
- Authentication flow (login, register, onboarding)
- Home screen with map and walk controls
- Active walk tracking with real-time updates
- Walk history and statistics
- Social feed with posts and interactions
- Dog profile management
- User settings and preferences

### ViewModels
- Manage view state
- Handle user actions
- Coordinate service calls
- Transform data for display
- Implement navigation logic

### Services
- **AuthService**: Firebase Authentication
- **LocationService**: Core Location integration
- **WalkTrackingService**: GPS tracking and route recording
- **MapService**: Google Maps integration
- **NetworkService**: API calls with Alamofire
- **NotificationService**: Push notifications
- **ImageService**: Image upload/download with Kingfisher
- **RoutingService**: Route calculation and optimization

### Repositories
- Abstract data source details
- Implement caching strategies
- Handle offline data
- Synchronize with Firebase
- Manage local database

## Dependency Management

### CocoaPods
- Firebase SDK (Auth, Firestore, Storage, Messaging, etc.)
- Google Sign-In
- Google Maps and Places
- Alamofire (networking)
- Kingfisher (image loading)

### Swift Package Manager (Optional)
- Can be used alongside CocoaPods
- Native Xcode integration

## Testing Structure

### Unit Tests
- Model validation tests
- ViewModel logic tests
- Service functionality tests
- Repository data operations
- Utility function tests

### UI Tests
- User flow testing
- Navigation testing
- Form validation
- Map interactions

## Configuration Files

### Info.plist
- App metadata
- Bundle identifier
- Permissions (location, camera, photos)
- URL schemes
- Background modes

### GoogleService-Info.plist
- Firebase configuration
- API keys
- Project identifiers
- Not in version control

### secrets.plist
- API keys
- Environment-specific values
- Not in version control

### Podfile
- Dependency declarations
- Platform and version requirements
- Post-install configurations

## Build Targets

### WoofWalk (Main App)
- Production app target
- All features enabled
- Release and Debug configurations

### WoofWalkTests
- Unit test target
- XCTest framework
- Code coverage enabled

### Future Targets
- WoofWalkUITests (UI testing)
- WoofWalkNotificationExtension (Notification service)
- WoofWalkWidgets (Home screen widgets)

## Code Organization Best Practices

### File Naming
- Use descriptive names: `WalkTrackingService.swift`
- Match class/struct name to file name
- Group related files in folders

### Code Style
- Swift naming conventions
- Consistent indentation
- Clear comments for complex logic
- Use extensions for protocol conformance

### Separation of Concerns
- Views only handle UI
- ViewModels manage state
- Services contain business logic
- Repositories handle data
- Models are pure data

### Dependency Injection
- Pass dependencies through initializers
- Use protocols for abstraction
- Enable testing with mocks

## Resource Organization

### Assets.xcassets
- App icon
- Launch images
- Image assets
- Color sets
- Symbol variants

### Localization
- en.lproj (English)
- Future: Additional language support

## Development Workflow

### Initial Setup
1. Clone repository
2. Run `pod install`
3. Add Firebase config
4. Add secrets.plist
5. Open .xcworkspace
6. Build and run

### Daily Development
1. Create feature branch
2. Implement in appropriate layer
3. Write unit tests
4. Test on simulator/device
5. Commit and push
6. Create pull request

### Code Review Checklist
- Follows MVVM pattern
- No business logic in views
- Services properly abstracted
- Tests included
- Documentation updated
- No hardcoded values

## Scalability Considerations

### Modular Architecture
- Features can be extracted to frameworks
- Shared code in separate modules
- Easy to add new features

### Performance
- Lazy loading of data
- Image caching with Kingfisher
- Efficient map rendering
- Background location updates

### Offline Support
- Local Core Data cache
- Queue for offline actions
- Sync when connection restored

### Future Enhancements
- Widget support
- Watch app
- Today extension
- Share extension
- Siri shortcuts

## Next Implementation Steps

1. Create all model files
2. Implement authentication service and views
3. Build location tracking service
4. Implement map view with Google Maps
5. Create walk tracking functionality
6. Add Firebase repository layer
7. Implement social features
8. Add local database caching
9. Write comprehensive tests
10. Polish UI and UX

## Related Documentation

- `/mnt/c/app/WoofWalk` - Android implementation reference
- `README.md` - Setup and overview
- `SETUP_CHECKLIST.md` - Step-by-step setup
- `BUILD_CONFIGURATION.md` - Build settings and deployment
