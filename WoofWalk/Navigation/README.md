# WoofWalk iOS Navigation System

This directory contains the SwiftUI NavigationStack-based navigation system ported from the Android Jetpack Navigation implementation.

## Architecture Overview

The navigation system uses SwiftUI's modern NavigationStack API with the following components:

### Core Components

1. **Route.swift**
   - Defines all application routes as an enum
   - Hashable routes for NavigationPath
   - Support for parameterized routes (POI details, dog stats, chat messages)
   - Deep link URL mapping

2. **NavigationViewModel.swift**
   - Central navigation state management
   - NavigationPath for stack-based navigation
   - Tab selection state
   - Sheet presentation state
   - Alert presentation state
   - Deep link handling
   - Programmatic navigation methods

3. **AppNavigator.swift**
   - Root navigation container
   - NavigationStack setup
   - Route-to-view mapping
   - Environment object injection
   - Deep link URL handling
   - Sheet and alert presentation

4. **MainTabView.swift**
   - Bottom tab bar implementation
   - Four tabs: Map, Feed, Social, Profile
   - Independent navigation stacks per tab
   - Sheet management for POI filters, dog selection
   - Tab-specific navigation paths

5. **TabItem.swift**
   - Tab bar item definitions
   - Icons and labels for each tab
   - Route associations

## Navigation Routes

### Authentication Flow
- `onboarding` - First launch onboarding
- `login` - Login screen
- `signup` - Registration screen
- `forgotPassword` - Password reset
- `profileSetup` - Initial profile setup after signup

### Main Tabs
- `map` - Map view with walk tracking
- `feed` - Activity feed
- `social` - Social hub
- `profile` - User profile

### Map Features
- `walkTracking` - Active walk tracking
- `addPoi(location)` - Add point of interest
- `poiDetail(poiId)` - POI detail view
- `walkHistory` - Walk history list

### Profile Features
- `stats` - User statistics
- `badges` - Achievement badges
- `leaderboard` - Leaderboard rankings
- `editProfile` - Edit user profile
- `dogStats(dogId)` - Individual dog statistics

### Settings
- `settings` - Main settings screen
- `alertHistory` - Alert history
- `alertSettings` - Alert preferences

### Social Features
- `chats` - Chat list
- `chatMessage(chatId)` - Chat conversation
- `lostDogsFeed` - Lost dogs feed
- `reportLostDog` - Report lost dog

## Deep Linking

The app supports deep links with the `woofwalk://` scheme:

### Supported Deep Links

```
woofwalk://walk/{walkId}     - Navigate to walk details
woofwalk://dog/{dogId}       - Navigate to dog stats
woofwalk://poi/{poiId}       - Navigate to POI details
woofwalk://chat/{chatId}     - Navigate to chat conversation
```

### Deep Link Handling

Deep links are processed in `NavigationViewModel.handleDeepLink()`:
1. Parse URL scheme and path
2. Extract route parameters
3. Navigate to appropriate tab
4. Push detail view onto navigation stack

## Navigation Methods

### NavigationViewModel API

```swift
// Stack navigation
navigate(to: Route)              // Push route onto stack
navigateBack()                   // Pop current route
navigateToRoot()                 // Pop to root
popTo(route: Route)              // Pop to specific route

// Tab navigation
selectTab(TabItem)               // Switch to tab (resets stack if same tab)

// Modal presentation
presentSheet(Route)              // Show route as sheet
dismissSheet()                   // Dismiss active sheet

// Alerts
showAlert(AppAlert)              // Show alert
dismissAlert()                   // Dismiss alert

// Deep links
handleDeepLink(URL)              // Process deep link URL
```

## Navigation Patterns

### Push Navigation
```swift
navigationViewModel.navigate(to: .poiDetail(poiId: "123"))
```

### Tab Switching
```swift
navigationViewModel.selectTab(.profile)
```

### Sheet Presentation
```swift
navigationViewModel.presentSheet(.addPoi(location: coords))
```

### Back Navigation
```swift
navigationViewModel.navigateBack()
```

### Root Reset
```swift
navigationViewModel.navigateToRoot()
```

## State Management

### Navigation State
- `navigationPath: NavigationPath` - Current navigation stack
- `selectedTab: TabItem` - Active tab
- `showSheet: Route?` - Sheet presentation state
- `activeAlert: AppAlert?` - Alert presentation state

### Environment Objects
- `NavigationViewModel` - Navigation state and methods
- `AuthViewModel` - Authentication state

## Tab Bar Structure

The bottom tab bar contains four tabs:

1. **Map Tab** (Default)
   - Icon: map
   - Route: .map
   - Root: MapView

2. **Feed Tab**
   - Icon: rectangle.stack
   - Route: .feed
   - Root: FeedView

3. **Social Tab**
   - Icon: person.2
   - Route: .social
   - Root: SocialHubView

4. **Profile Tab**
   - Icon: person
   - Route: .profile
   - Root: ProfileView

Each tab maintains its own navigation stack. Tapping the active tab resets its stack to root.

## Comparison with Android Navigation

### Android (Jetpack Compose)
```kotlin
Screen.PoiDetail.route = "poi_detail/{poiId}"
navController.navigate(Screen.PoiDetail.createRoute(poiId))
```

### iOS (SwiftUI)
```swift
Route.poiDetail(poiId: String)
navigationViewModel.navigate(to: .poiDetail(poiId: id))
```

### Key Differences

1. **Type Safety**
   - Android: String-based routes with runtime parsing
   - iOS: Enum-based routes with compile-time type safety

2. **Navigation Controller**
   - Android: NavHostController per navigation graph
   - iOS: Single NavigationPath with enum routing

3. **Tab Navigation**
   - Android: Separate NavHost inside bottom nav scaffold
   - iOS: TabView with independent NavigationStacks

4. **Deep Links**
   - Android: navDeepLink in navigation graph
   - iOS: .onOpenURL modifier with manual parsing

## Usage Example

```swift
struct ContentView: View {
    var body: some View {
        AppNavigator()
    }
}

struct MapView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel

    var body: some View {
        VStack {
            // Map content
            Button("View POI") {
                navigationViewModel.navigate(to: .poiDetail(poiId: "123"))
            }
        }
    }
}
```

## Future Enhancements

1. Navigation state persistence across app launches
2. Custom transition animations
3. Navigation history tracking/analytics
4. Back gesture customization
5. Split view support for iPad
6. Handoff support between devices
7. Universal Links support
8. Navigation testing utilities
