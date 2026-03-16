# WoofWalk iOS Navigation Flow Diagram

## Application Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      App Launch                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
              ┌────────────────┐
              │ Start Route    │
              │ Determination  │
              └────┬───┬───┬───┘
                   │   │   │
        ┌──────────┘   │   └──────────┐
        │              │              │
        ▼              ▼              ▼
   First Launch?   Logged In?   Has Profile?
        │              │              │
        ▼              ▼              ▼
   Onboarding      Login/Signup   Map (Main)
```

## Authentication Flow

```
┌──────────────┐
│  Onboarding  │
└──────┬───────┘
       │
       ▼
┌──────────────┐         ┌──────────────┐
│    Login     │◄────────┤ ForgotPassword│
└──┬────────┬──┘         └──────────────┘
   │        │
   │        └──────┐
   ▼               ▼
┌──────────┐   ┌──────────────┐
│  Signup  │   │ProfileSetup  │
└─────┬────┘   └──────┬───────┘
      │               │
      └───────┬───────┘
              │
              ▼
      ┌──────────────┐
      │  Main Tabs   │
      └──────────────┘
```

## Main Tab Structure

```
┌─────────────────────────────────────────────────────────────┐
│                      Main Tab View                           │
├─────────────┬─────────────┬─────────────┬──────────────────┤
│             │             │             │                   │
│   Map Tab   │  Feed Tab   │ Social Tab  │  Profile Tab     │
│   (Home)    │             │             │                   │
│             │             │             │                   │
└─────────────┴─────────────┴─────────────┴──────────────────┘
      │              │             │              │
      │              │             │              │
      ▼              ▼             ▼              ▼
  [Map Stack]   [Feed Stack]  [Social Stack] [Profile Stack]
```

## Map Tab Navigation Stack

```
┌──────────────┐
│   MapView    │ (Root)
│   (Home)     │
└──────┬───────┘
       │
       ├──────────────► ┌──────────────┐
       │                │ WalkTracking │
       │                └──────────────┘
       │
       ├──────────────► ┌──────────────┐
       │                │ POI Detail   │
       │                └──────────────┘
       │
       ├──────────────► ┌──────────────┐
       │                │ Walk History │
       │                └──────────────┘
       │
       └──────────────► ┌──────────────┐
                        │  Settings    │
                        └──────┬───────┘
                               │
                               ├──► ┌────────────────┐
                               │    │ Alert History  │
                               │    └────────────────┘
                               │
                               └──► ┌────────────────┐
                                    │ Alert Settings │
                                    └────────────────┘

Sheets (Modal):
┌──────────────┐
│   Add POI    │
└──────────────┘
┌──────────────┐
│ POI Filter   │
└──────────────┘
┌──────────────┐
│Dog Selection │
└──────────────┘
```

## Profile Tab Navigation Stack

```
┌──────────────┐
│ ProfileView  │ (Root)
└──────┬───────┘
       │
       ├──────────────► ┌──────────────┐
       │                │    Stats     │
       │                └──────────────┘
       │
       ├──────────────► ┌──────────────┐
       │                │   Badges     │
       │                └──────────────┘
       │
       ├──────────────► ┌──────────────┐
       │                │ Leaderboard  │
       │                └──────────────┘
       │
       ├──────────────► ┌──────────────┐
       │                │ Edit Profile │
       │                └──────────────┘
       │
       ├──────────────► ┌──────────────┐
       │                │   Settings   │
       │                └──────────────┘
       │
       └──────────────► ┌──────────────┐
                        │  Dog Stats   │
                        │  (dogId)     │
                        └──────────────┘
```

## Social Tab Navigation Stack

```
┌──────────────┐
│ SocialHub    │ (Root)
└──────┬───────┘
       │
       ├──────────────► ┌──────────────┐
       │                │  Chat List   │
       │                └──────┬───────┘
       │                       │
       │                       └──► ┌──────────────┐
       │                            │Chat Message  │
       │                            │  (chatId)    │
       │                            └──────────────┘
       │
       ├──────────────► ┌──────────────┐
       │                │Lost Dogs Feed│
       │                └──────────────┘
       │
       └──────────────► ┌──────────────┐
                        │Report Lost   │
                        │    Dog       │
                        └──────────────┘
```

## Feed Tab Navigation Stack

```
┌──────────────┐
│  FeedView    │ (Root)
└──────────────┘
       │
       │ (To be implemented)
       │
       ▼
  [Future routes]
```

## Deep Link Flow

```
Deep Link URL: woofwalk://dog/123
       │
       ▼
┌──────────────────┐
│ handleDeepLink() │
└────────┬─────────┘
         │
         ├─ Parse URL
         ├─ Extract parameters
         ├─ Determine target tab
         └─ Build navigation path
              │
              ▼
┌──────────────────────────┐
│1. selectTab(.profile)    │
│2. navigate(to:           │
│   .dogStats(dogId: "123")│
└──────────────────────────┘
```

## Deep Link Routing Table

```
┌─────────────────────┬──────────────┬─────────────────────┐
│      URL            │  Target Tab  │    Final Route      │
├─────────────────────┼──────────────┼─────────────────────┤
│ woofwalk://walk/id  │     Map      │ .poiDetail(id)      │
│ woofwalk://dog/id   │   Profile    │ .dogStats(id)       │
│ woofwalk://poi/id   │     Map      │ .poiDetail(id)      │
│ woofwalk://chat/id  │    Social    │ .chatMessage(id)    │
└─────────────────────┴──────────────┴─────────────────────┘
```

## Navigation State Machine

```
┌─────────────────────────────────────────────────────────┐
│           NavigationViewModel State                     │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  navigationPath: NavigationPath                         │
│    └─► Stack of Route enums                             │
│                                                          │
│  selectedTab: TabItem                                   │
│    └─► Currently active tab (.map | .feed | .social |  │
│                                .profile)                │
│                                                          │
│  showSheet: Route?                                      │
│    └─► Modal sheet presentation                         │
│                                                          │
│  activeAlert: AppAlert?                                 │
│    └─► Alert presentation                               │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Method Call Flow

### Push Navigation
```
User Action
    ↓
Button Tap
    ↓
navigationViewModel.navigate(to: .settings)
    ↓
navigationPath.append(.settings)
    ↓
SwiftUI NavigationStack
    ↓
.navigationDestination(for: Route.self)
    ↓
SettingsView displayed
```

### Tab Switch
```
User Action
    ↓
Tab Bar Tap
    ↓
navigationViewModel.selectTab(.profile)
    ↓
if selectedTab == .profile {
    navigationPath = NavigationPath()  // Reset stack
} else {
    selectedTab = .profile             // Switch tab
}
    ↓
TabView selection updates
    ↓
Profile tab stack displayed
```

### Sheet Presentation
```
User Action
    ↓
Button Tap
    ↓
navigationViewModel.presentSheet(.addPoi(location))
    ↓
showSheet = .addPoi(location)
    ↓
.sheet(item: $showSheet)
    ↓
AddPoiView displayed as modal
```

## Environment Object Flow

```
┌──────────────────┐
│   AppNavigator   │
│   (Root)         │
│                  │
│  @StateObject    │
│  navigationVM    │
│  authVM          │
└────────┬─────────┘
         │
         │ .environmentObject(navigationVM)
         │ .environmentObject(authVM)
         │
         ▼
┌──────────────────┐
│  NavigationStack │
└────────┬─────────┘
         │
         │ Inherited
         │
         ▼
┌──────────────────┐
│   MainTabView    │
└────────┬─────────┘
         │
         │ Inherited
         │
         ▼
┌──────────────────┐
│   Child Views    │
│                  │
│  @EnvironmentObject
│  navigationVM    │
└──────────────────┘
```

## Complete Route Hierarchy

```
Route (enum)
├── Authentication
│   ├── onboarding
│   ├── login
│   ├── signup
│   ├── forgotPassword
│   └── profileSetup
│
├── Main Tabs
│   ├── map
│   ├── feed
│   ├── social
│   └── profile
│
├── Map Features
│   ├── walkTracking
│   ├── addPoi(LocationCoordinate?)
│   ├── poiDetail(String)
│   └── walkHistory
│
├── Profile Features
│   ├── stats
│   ├── badges
│   ├── leaderboard
│   ├── editProfile
│   └── dogStats(String)
│
├── Settings
│   ├── settings
│   ├── alertHistory
│   └── alertSettings
│
└── Social Features
    ├── chats
    ├── chatMessage(String)
    ├── lostDogsFeed
    └── reportLostDog
```

## Navigation Patterns Summary

### Pattern 1: Direct Push
```swift
navigationViewModel.navigate(to: .settings)
```

### Pattern 2: Pop Back
```swift
navigationViewModel.navigateBack()
```

### Pattern 3: Reset Stack
```swift
navigationViewModel.navigateToRoot()
```

### Pattern 4: Tab Switch
```swift
navigationViewModel.selectTab(.profile)
```

### Pattern 5: Modal Sheet
```swift
navigationViewModel.presentSheet(.addPoi(location))
```

### Pattern 6: Deep Link
```swift
// Automatic via .onOpenURL
// Manual test:
navigationViewModel.handleDeepLink(
    URL(string: "woofwalk://dog/123")!
)
```

---

**Visual Key:**
- `│` = Navigation path
- `►` = Push navigation
- `◄` = Back navigation
- `▼` = Flow direction
- `┌─┐` = Screen/View
- `[Stack]` = Navigation stack
