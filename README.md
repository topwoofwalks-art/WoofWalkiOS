# WoofWalk iOS

Dog walking companion app for iOS - Track walks, discover dog-friendly locations, and connect with other dog owners.

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- CocoaPods

## Project Structure

```
WoofWalkiOS/
├── WoofWalk.xcodeproj/        # Xcode project file
├── WoofWalk/                   # Main source directory
│   ├── Models/                 # Data models
│   ├── Views/                  # SwiftUI views
│   ├── ViewModels/             # View models (MVVM)
│   ├── Services/               # Service layer (networking, location, etc.)
│   ├── Repositories/           # Data repositories
│   ├── Database/               # Local database (Core Data/Realm)
│   ├── Utils/                  # Utility functions and extensions
│   ├── Resources/              # Assets, colors, fonts
│   ├── WoofWalkApp.swift      # App entry point
│   ├── ContentView.swift      # Main view
│   └── Info.plist             # App configuration
├── WoofWalkTests/             # Unit tests
├── Podfile                     # CocoaPods dependencies
└── README.md                   # This file
```

## Setup Instructions

### 1. Install Dependencies

```bash
cd /mnt/c/app/WoofWalkiOS
pod install
```

### 2. Firebase Configuration

1. Create Firebase project at https://console.firebase.google.com
2. Add iOS app with bundle ID: `com.woofwalk.ios`
3. Download `GoogleService-Info.plist`
4. Add to `WoofWalk/` directory
5. Enable required services:
   - Authentication (Email, Google Sign-In)
   - Firestore Database
   - Cloud Storage
   - Cloud Messaging
   - Crashlytics
   - Analytics

### 3. Google Maps API Key

1. Get API key from Google Cloud Console
2. Create `secrets.plist` in `WoofWalk/` directory:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GOOGLE_MAPS_API_KEY</key>
    <string>YOUR_API_KEY_HERE</string>
</dict>
</plist>
```

### 4. Open Project

```bash
# Open workspace (after pod install)
open WoofWalk.xcworkspace
```

### 5. Build Configuration

- **Debug**: Development build with debug symbols
- **Release**: Optimized production build

### 6. Run App

1. Select target device/simulator
2. Press Cmd+R to build and run

## Dependencies

### Firebase (10.20.0)
- Core
- Auth
- Firestore
- Storage
- Messaging
- Crashlytics
- Analytics

### Google Services
- Google Sign-In (7.1.0)
- Google Maps (8.4.0)
- Google Places (8.4.0)

### Networking & Image Loading
- Alamofire (5.9.0) - HTTP networking
- Kingfisher (7.11.0) - Image downloading and caching

## Key Features

- User authentication (Email, Google Sign-In)
- Real-time walk tracking with GPS
- Interactive maps with dog-friendly POIs
- Walk history and statistics
- Photo capture during walks
- Social features (follow, like, comment)
- Push notifications
- Offline data caching

## Architecture

- **MVVM Pattern**: Model-View-ViewModel
- **SwiftUI**: Declarative UI framework
- **Combine**: Reactive programming
- **Async/Await**: Modern concurrency
- **Dependency Injection**: Service-based architecture

## Permissions

App requires following permissions:

- **Location (Always/WhenInUse)**: Track walks
- **Camera**: Take photos during walks
- **Photo Library**: Save and access walk photos
- **Push Notifications**: Walk reminders and social updates

## Version

- **App Version**: 1.0.0
- **Build**: 1
- **Min iOS**: 16.0
- **Target iOS**: Latest

## Bundle Identifier

`com.woofwalk.ios`

## Next Steps

1. Install CocoaPods dependencies: `pod install`
2. Add Firebase configuration file
3. Configure Google Maps API key
4. Implement core models and services
5. Build out UI views and view models
6. Add unit and UI tests
7. Configure signing for device testing

## Development Notes

- Use SwiftUI for all UI components
- Follow Swift naming conventions
- Implement proper error handling
- Write unit tests for business logic
- Use async/await for asynchronous operations
- Leverage Combine for reactive data flow
- Cache data locally for offline access

## Build Settings

- **Swift Version**: 5.0
- **Deployment Target**: iOS 16.0
- **Supported Devices**: iPhone, iPad
- **Orientation**: Portrait (iPhone), All (iPad)
- **Scene Support**: Multiple scenes enabled

## Contact

For questions or issues, refer to Android implementation at `/mnt/c/app/WoofWalk`
