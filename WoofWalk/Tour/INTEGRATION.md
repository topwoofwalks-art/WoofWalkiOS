# Tour Framework Integration Guide

## Quick Start

### 1. Add TourCoordinator to App

```swift
@main
struct WoofWalkApp: App {
    @StateObject private var tourCoordinator = TourCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tourCoordinator)
        }
    }
}
```

### 2. Apply Tour Overlay to Root View

```swift
struct ContentView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        TabView {
            MapView()
                .tabItem { Label("Map", systemImage: "map") }

            SocialView()
                .tabItem { Label("Social", systemImage: "person.2") }
        }
        .tourOverlay(coordinator: tourCoordinator)
        .onAppear {
            checkInitialTour()
        }
    }

    private func checkInitialTour() {
        if tourCoordinator.shouldShowTour(.initialWalkthrough) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                tourCoordinator.startTour(.initialWalkthrough)
            }
        }
    }
}
```

### 3. Mark UI Elements as Tour Targets

```swift
struct MapView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        ZStack {
            Map(...)

            VStack {
                HStack {
                    Spacer()

                    VStack(spacing: 12) {
                        Button(action: { /* search */ }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .tourTarget(id: "search_button", coordinator: tourCoordinator)

                        Button(action: { /* filter */ }) {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                        .tourTarget(id: "filter_button", coordinator: tourCoordinator)

                        Button(action: { /* location */ }) {
                            Image(systemName: "location.fill")
                        }
                        .tourTarget(id: "location_button", coordinator: tourCoordinator)
                    }
                    .padding()
                }

                Spacer()

                HStack {
                    Spacer()

                    Button(action: { /* start walk */ }) {
                        Text("Start Walk")
                    }
                    .tourTarget(id: "start_walk_button", coordinator: tourCoordinator)
                    .padding()
                }
            }
        }
    }
}
```

### 4. Trigger Tours on Feature Access

```swift
struct SocialView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        TabView {
            FriendsView()
                .tabItem { Text("Friends") }
                .tag(0)

            EventsView()
                .tabItem { Text("Events") }
                .tag(1)
        }
        .onAppear {
            if tourCoordinator.shouldShowTour(.socialNavigationDemo) {
                tourCoordinator.startTour(.socialNavigationDemo)
            }
        }
    }
}
```

## Feature-Specific Tours

### Social Navigation Tour

Automatically show when user first accesses Social tab:

```swift
struct SocialView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator
    @State private var hasShownTour = false

    var body: some View {
        content
            .onAppear {
                if !hasShownTour && tourCoordinator.shouldShowTour(.socialNavigationDemo) {
                    hasShownTour = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        tourCoordinator.startTour(.socialNavigationDemo)
                    }
                }
            }
    }
}
```

### Field Drawing Tour

Show when user long presses map to enable drawing mode:

```swift
struct MapView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator
    @State private var isDrawingMode = false

    var body: some View {
        Map(...)
            .gesture(
                LongPressGesture(minimumDuration: 1.0)
                    .onEnded { _ in
                        isDrawingMode = true

                        if tourCoordinator.shouldShowTour(.fieldDrawingDemo) {
                            tourCoordinator.startTour(.fieldDrawingDemo)
                        }
                    }
            )
    }
}
```

### Map Features Tour

Show on first map view load or via help button:

```swift
struct MapView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        ZStack {
            mapContent

            VStack {
                HStack {
                    Button(action: showMapTour) {
                        Image(systemName: "questionmark.circle")
                    }
                    .padding()

                    Spacer()
                }

                Spacer()
            }
        }
        .onAppear {
            if tourCoordinator.shouldShowTour(.mapFeaturesDemo) {
                tourCoordinator.startTour(.mapFeaturesDemo)
            }
        }
    }

    private func showMapTour() {
        tourCoordinator.resetTour(.mapFeaturesDemo)
        tourCoordinator.startTour(.mapFeaturesDemo)
    }
}
```

## Advanced Usage

### Custom Tour for Onboarding

```swift
struct OnboardingView: View {
    @StateObject private var tourCoordinator = TourCoordinator()

    var body: some View {
        content
            .tourOverlay(coordinator: tourCoordinator)
            .onAppear {
                createOnboardingTour()
            }
    }

    private func createOnboardingTour() {
        let steps = [
            TourStep(
                id: "welcome",
                title: "Welcome to WoofWalk!",
                description: "Let's take a quick tour of the app features.",
                position: .center
            ),
            TourStep(
                id: "map_intro",
                title: "Interactive Map",
                description: "Discover dog parks, water fountains, and pet-friendly places nearby.",
                targetViewId: "map_tab",
                spotlightShape: .roundedRectangle(cornerRadius: 12),
                position: .bottom
            ),
            TourStep(
                id: "social_intro",
                title: "Connect with Others",
                description: "Find friends, join group walks, and participate in events.",
                targetViewId: "social_tab",
                spotlightShape: .roundedRectangle(cornerRadius: 12),
                position: .bottom
            ),
            TourStep(
                id: "profile_intro",
                title: "Your Profile",
                description: "Track your walks, earn achievements, and customize your experience.",
                targetViewId: "profile_tab",
                spotlightShape: .roundedRectangle(cornerRadius: 12),
                position: .bottom
            )
        ]

        tourCoordinator.registerCustomTour(.custom, steps: steps)
        tourCoordinator.startTour(.custom)

        tourCoordinator.setOnTourCompleteCallback { _ in
            markOnboardingComplete()
        }
    }

    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
    }
}
```

### Contextual Help Tour

```swift
struct FeatureView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: showHelp) {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
    }

    private func showHelp() {
        let steps = [
            TourStep(
                id: "feature_overview",
                title: "Feature Overview",
                description: "This feature allows you to...",
                position: .center
            ),
            TourStep(
                id: "action_button",
                title: "Main Action",
                description: "Tap here to perform the main action.",
                targetViewId: "action_button",
                position: .center
            )
        ]

        tourCoordinator.registerCustomTour(.custom, steps: steps)
        tourCoordinator.startTour(.custom)
    }
}
```

### Tour with Actions

```swift
struct DrawingView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator
    @State private var isDrawingMode = false

    var body: some View {
        content
            .onAppear {
                setupDrawingTour()
            }
    }

    private func setupDrawingTour() {
        tourCoordinator.setOnStepChangeCallback { step in
            switch step.id {
            case "draw_enable":
                isDrawingMode = true
            case "draw_complete":
                isDrawingMode = false
            default:
                break
            }
        }
    }
}
```

## Testing

### Reset Tours for Development

```swift
#if DEBUG
struct DeveloperSettingsView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        List {
            Section("Tours") {
                Button("Reset All Tours") {
                    resetAllTours()
                }

                Button("Show Social Tour") {
                    tourCoordinator.startTour(.socialNavigationDemo)
                }

                Button("Show Drawing Tour") {
                    tourCoordinator.startTour(.fieldDrawingDemo)
                }

                Button("Show Map Tour") {
                    tourCoordinator.startTour(.mapFeaturesDemo)
                }
            }
        }
    }

    private func resetAllTours() {
        let persistence = TourPersistence()
        persistence.resetAllTours()
    }
}
#endif
```

### Preview with Tour

```swift
#Preview {
    let coordinator = TourCoordinator()

    ContentView()
        .environmentObject(coordinator)
        .onAppear {
            coordinator.startTour(.mapFeaturesDemo)
        }
}
```

## Performance Considerations

### Lazy Tour Loading

```swift
struct ContentView: View {
    @StateObject private var tourCoordinator = TourCoordinator()
    @State private var isContentLoaded = false

    var body: some View {
        content
            .tourOverlay(coordinator: tourCoordinator)
            .onAppear {
                isContentLoaded = true
            }
            .onChange(of: isContentLoaded) { loaded in
                if loaded {
                    checkTours()
                }
            }
    }

    private func checkTours() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if tourCoordinator.shouldShowTour(.initialWalkthrough) {
                tourCoordinator.startTour(.initialWalkthrough)
            }
        }
    }
}
```

### Debounced Tour Checks

```swift
class TourManager: ObservableObject {
    private let coordinator: TourCoordinator
    private var tourCheckWorkItem: DispatchWorkItem?

    init(coordinator: TourCoordinator) {
        self.coordinator = coordinator
    }

    func checkTour(_ tourType: TourType, delay: TimeInterval = 0.5) {
        tourCheckWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.coordinator.shouldShowTour(tourType) {
                self.coordinator.startTour(tourType)
            }
        }

        tourCheckWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
```

## Troubleshooting

### Tour Not Showing

1. Check if tour overlay is applied to root view
2. Verify `shouldShowTour()` returns true
3. Check UserDefaults for completion flags
4. Ensure tour targets are properly registered

### Spotlight Not Highlighting Correctly

1. Verify target ID matches between `.tourTarget()` and `TourStep.targetViewId`
2. Ensure GeometryReader is capturing frame correctly
3. Check if view is visible when tour starts
4. Try adding delay before starting tour

### Tour Persistence Issues

1. Check UserDefaults keys are correct
2. Verify reset functions are working
3. Clear app data and retry
4. Check for UserDefaults synchronization

## Migration from Android

### Key Differences

**Android (Compose)**
```kotlin
TourCoordinator(context, preferences)
tourDefinitions[TourType.SOCIAL_NAVIGATION_DEMO] = listOf(...)
_currentTour.value = TourProgress(...)
```

**iOS (SwiftUI)**
```swift
TourCoordinator(userDefaults: .standard)
tourDefinitions[.socialNavigationDemo] = [...]
currentTour = TourProgress(...)
```

### StateFlow → @Published

**Android**
```kotlin
val currentTour: StateFlow<TourProgress?>
```

**iOS**
```swift
@Published private(set) var currentTour: TourProgress?
```

### Preference Keys → UserDefaults

**Android**
```kotlin
preferences.getBoolean("tour_social_demo_shown", false)
preferences.edit().putBoolean("tour_social_demo_shown", true).apply()
```

**iOS**
```swift
userDefaults.bool(forKey: "tour_shown_SOCIAL_NAVIGATION_DEMO")
userDefaults.set(true, forKey: "tour_shown_SOCIAL_NAVIGATION_DEMO")
```

## Best Practices

1. **Delay tour start**: Wait 0.5-1s after view appears for smooth UX
2. **Mark targets early**: Apply `.tourTarget()` before tour starts
3. **Handle callbacks**: Use callbacks for navigation & state changes
4. **Test thoroughly**: Reset tours frequently during development
5. **Track analytics**: Monitor completion rates & skip points
6. **Keep steps concise**: 3-6 steps per tour, <100 words per description
7. **Use appropriate shapes**: Circle for buttons, rounded rect for cards
8. **Respect user choice**: Honor "don't show again" preferences
