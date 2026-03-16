# Tour Framework Quick Start

## 5-Minute Integration

### Step 1: Add to App (30 seconds)

```swift
// WoofWalkApp.swift
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

### Step 2: Apply Overlay (30 seconds)

```swift
// ContentView.swift
struct ContentView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        TabView {
            MapView()
            SocialView()
            ProfileView()
        }
        .tourOverlay(coordinator: tourCoordinator)
    }
}
```

### Step 3: Mark Targets (2 minutes)

```swift
// MapView.swift
struct MapView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        ZStack {
            Map(...)

            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        searchButton
                        filterButton
                        locationButton
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    startWalkButton
                }
            }
        }
    }

    var searchButton: some View {
        Button { /* action */ } label: {
            Image(systemName: "magnifyingglass")
        }
        .tourTarget(id: "search_button", coordinator: tourCoordinator)
    }

    var filterButton: some View {
        Button { /* action */ } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .tourTarget(id: "filter_button", coordinator: tourCoordinator)
    }

    var locationButton: some View {
        Button { /* action */ } label: {
            Image(systemName: "location.fill")
        }
        .tourTarget(id: "location_button", coordinator: tourCoordinator)
    }

    var startWalkButton: some View {
        Button { /* action */ } label: {
            Text("Start Walk")
        }
        .tourTarget(id: "start_walk_button", coordinator: tourCoordinator)
    }
}
```

### Step 4: Trigger Tour (1 minute)

```swift
// MapView.swift (add to existing view)
struct MapView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        // ... existing code ...
        .onAppear {
            if tourCoordinator.shouldShowTour(.mapFeaturesDemo) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tourCoordinator.startTour(.mapFeaturesDemo)
                }
            }
        }
    }
}
```

### Step 5: Done!

That's it! Your tour is now functional. The framework handles:
- Spotlight effect w/ pulse animation
- Step navigation (next, previous, skip)
- Persistence (won't show again after completion)
- Tour card UI w/ title & description

## Common Patterns

### Pattern: First-Time User Onboarding

```swift
struct ContentView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        content
            .tourOverlay(coordinator: tourCoordinator)
            .onAppear {
                checkInitialTour()
            }
    }

    private func checkInitialTour() {
        if tourCoordinator.shouldShowTour(.initialWalkthrough) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                tourCoordinator.startTour(.initialWalkthrough)
            }
        }
    }
}
```

### Pattern: Feature Discovery Tour

```swift
struct SocialView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator
    @State private var hasShownTour = false

    var body: some View {
        content
            .onAppear {
                showTourIfNeeded()
            }
    }

    private func showTourIfNeeded() {
        guard !hasShownTour else { return }
        hasShownTour = true

        if tourCoordinator.shouldShowTour(.socialNavigationDemo) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                tourCoordinator.startTour(.socialNavigationDemo)
            }
        }
    }
}
```

### Pattern: Help Button

```swift
struct MapView: View {
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
        tourCoordinator.resetTour(.mapFeaturesDemo)
        tourCoordinator.startTour(.mapFeaturesDemo)
    }
}
```

### Pattern: Custom Tour

```swift
func createCustomTour() {
    let steps = [
        TourStep(
            id: "step1",
            title: "Welcome",
            description: "This is the first step.",
            targetViewId: "button1",
            spotlightShape: .circle,
            position: .center
        ),
        TourStep(
            id: "step2",
            title: "Next Feature",
            description: "This is the second step.",
            targetViewId: "button2",
            spotlightShape: .roundedRectangle(cornerRadius: 12),
            position: .topRight1
        )
    ]

    tourCoordinator.registerCustomTour(.custom, steps: steps)
    tourCoordinator.startTour(.custom)
}
```

### Pattern: Tour Callbacks

```swift
struct ContentView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        content
            .onAppear {
                setupCallbacks()
            }
    }

    private func setupCallbacks() {
        tourCoordinator.setOnStepChangeCallback { step in
            print("Step: \(step.title)")
            // Analytics, navigation, etc.
        }

        tourCoordinator.setOnTourCompleteCallback { tourType in
            print("Completed: \(tourType)")
            // Show success message, unlock features
        }

        tourCoordinator.setOnTourSkipCallback { tourType in
            print("Skipped: \(tourType)")
            // Show alternative onboarding
        }
    }
}
```

### Pattern: Developer Settings

```swift
#if DEBUG
struct DeveloperSettingsView: View {
    @EnvironmentObject var tourCoordinator: TourCoordinator

    var body: some View {
        List {
            Section("Tours") {
                Button("Reset All Tours") { resetAllTours() }
                Button("Social Tour") { tourCoordinator.startTour(.socialNavigationDemo) }
                Button("Drawing Tour") { tourCoordinator.startTour(.fieldDrawingDemo) }
                Button("Map Tour") { tourCoordinator.startTour(.mapFeaturesDemo) }
            }

            Section("Statistics") {
                ForEach(tourCoordinator.getAllTourStats(), id: \.tourType.rawValue) { stats in
                    HStack {
                        Text(stats.tourType.rawValue)
                        Spacer()
                        Text(stats.status)
                    }
                }
            }
        }
    }

    private func resetAllTours() {
        TourPersistence().resetAllTours()
    }
}
#endif
```

## Predefined Tours

### Social Navigation Demo

```swift
tourCoordinator.startTour(.socialNavigationDemo)
```

**Steps**:
1. Social features intro
2. Friends tab
3. Events tab
4. Group walks tab
5. Chats tab
6. Lost dogs alert

**Target IDs**:
- `bottom_nav_social`
- `social_tab_friends`
- `social_tab_events`
- `social_tab_group_walks`
- `social_tab_chats`
- `social_tab_lost_dogs`

### Field Drawing Demo

```swift
tourCoordinator.startTour(.fieldDrawingDemo)
```

**Steps**:
1. Drawing intro
2. Enable drawing mode
3. Add points
4. Complete drawing
5. Delete fields

**Target IDs**:
- `map_view`
- `draw_complete_button`
- `draw_delete_button`

### Map Features Demo

```swift
tourCoordinator.startTour(.mapFeaturesDemo)
```

**Steps**:
1. Search button
2. Filter button
3. Location button
4. Start walk button

**Target IDs**:
- `search_button`
- `filter_button`
- `location_button`
- `start_walk_button`

## Testing

### Reset Tours

```swift
// Reset specific tour
tourCoordinator.resetTour(.socialNavigationDemo)

// Reset all tours
let persistence = TourPersistence()
persistence.resetAllTours()
```

### Check Tour Status

```swift
// Should show?
let shouldShow = tourCoordinator.shouldShowTour(.mapFeaturesDemo)

// Get stats
let stats = tourCoordinator.getTourStats(.mapFeaturesDemo)
print("Status: \(stats.status)")
print("Completed: \(stats.isCompleted)")
print("Skipped: \(stats.isSkipped)")
print("Seen steps: \(stats.seenStepsCount)")
```

### Preview Tours

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

## Troubleshooting

### Tour not showing?

1. Check overlay applied: `.tourOverlay(coordinator: tourCoordinator)`
2. Check `shouldShowTour()` returns true
3. Reset tour: `tourCoordinator.resetTour(.mapFeaturesDemo)`
4. Add delay: `DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ... }`

### Spotlight not highlighting?

1. Verify target ID matches: `.tourTarget(id: "button_id", ...)`
2. Check view is visible when tour starts
3. Ensure GeometryReader captures frame
4. Try increasing spotlight radius

### Tour persists after reset?

1. Clear UserDefaults: `TourPersistence().resetAllTours()`
2. Check for custom persistence logic
3. Verify `shouldShowTour()` logic

## Next Steps

1. Read [README.md](README.md) for full documentation
2. Check [INTEGRATION.md](INTEGRATION.md) for advanced patterns
3. Review [ARCHITECTURE.md](ARCHITECTURE.md) for internals
4. See [TourExampleUsage.swift](TourExampleUsage.swift) for live examples

---

**Time to implement**: ~5 minutes
**Lines of code**: ~20 (basic setup)
**Dependencies**: Zero
**Complexity**: Low
**Maintenance**: Minimal
