# Tour/Tutorial Framework

SwiftUI-based tour & tutorial system ported from Android WoofWalk app.

## Architecture

### Core Components

**TourModels.swift** (184 lines)
- `TourType`: Tour categories (initial, social, field drawing, map features)
- `TourState`: Tour lifecycle states (not started, in progress, paused, completed, skipped)
- `TourStep`: Individual step w/ title, description, target UI element, spotlight config
- `SpotlightShape`: Highlight shapes (circle, rectangle, rounded rectangle)
- `SpotlightPosition`: Predefined positions (top left/right, bottom, center)
- `TourAction` protocol: Executable actions per step
- `TourProgress`: Current tour state tracking
- `HighlightConfig`: Spotlight effect configuration
- `TourAnnotation`: On-screen text annotations w/ styling

**TourCoordinator.swift** (371 lines)
- `@MainActor class TourCoordinator`: Tour state manager
- `@Published` properties: currentTour, highlightedElement, overlayMessage, activeAnnotations
- Tour lifecycle: start, next, previous, pause, resume, skip, complete
- Persistence: UserDefaults-based completion tracking
- Callbacks: onStepChange, onTourComplete, onTourSkip
- Default tours: social navigation, field drawing, map features
- Custom tour registration
- Tour replay functionality

**TourSpotlightView.swift** (247 lines)
- `TourSpotlightView`: Main overlay w/ dimmed background + spotlight + tour card
- Spotlight shapes: Circle, Rectangle, RoundedRectangle w/ pulse animation
- Tour card: Title, description, navigation buttons (skip, previous, next)
- `TourOverlayModifier`: Apply tour overlay to any view
- `TourTargetModifier`: Mark UI elements as tour targets w/ frame tracking
- `AnnotationView`: Display styled annotations
- `TourTargetPreferenceKey`: GeometryReader-based frame capture

**TourPersistence.swift** (162 lines)
- `TourPersistence`: UserDefaults wrapper for tour data
- Tour completion tracking w/ dates
- Individual step seen tracking
- "Don't show again" functionality
- Tour stats: completion status, seen steps count
- Reset tours individually or all at once
- `TourStats`: Tour progress summary

## Usage

### Basic Setup

```swift
@StateObject private var tourCoordinator = TourCoordinator()

var body: some View {
    ContentView()
        .tourOverlay(coordinator: tourCoordinator)
        .onAppear {
            if tourCoordinator.shouldShowTour(.initialWalkthrough) {
                tourCoordinator.startTour(.initialWalkthrough)
            }
        }
}
```

### Mark UI Elements as Tour Targets

```swift
Button("Social") {
    // Action
}
.tourTarget(id: "bottom_nav_social", coordinator: tourCoordinator)
```

### Custom Tour

```swift
let customSteps = [
    TourStep(
        id: "step1",
        title: "Welcome",
        description: "This is step 1",
        targetViewId: "my_button",
        spotlightShape: .circle,
        position: .center
    ),
    TourStep(
        id: "step2",
        title: "Next Feature",
        description: "This is step 2",
        targetViewId: "my_other_button",
        spotlightShape: .roundedRectangle(cornerRadius: 12),
        position: .topRight1
    )
]

tourCoordinator.registerCustomTour(.custom, steps: customSteps)
tourCoordinator.startTour(.custom)
```

### Callbacks

```swift
tourCoordinator.setOnStepChangeCallback { step in
    print("Current step: \(step.title)")
}

tourCoordinator.setOnTourCompleteCallback { tourType in
    print("Tour completed: \(tourType)")
}

tourCoordinator.setOnTourSkipCallback { tourType in
    print("Tour skipped: \(tourType)")
}
```

### Annotations

```swift
tourCoordinator.addAnnotation(
    TourAnnotation(
        position: CGPoint(x: 100, y: 200),
        text: "Tap here!",
        style: .highlight
    )
)

tourCoordinator.clearAnnotations()
```

### Overlay Messages

```swift
tourCoordinator.showOverlayMessage("Loading next step...")

DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    tourCoordinator.hideOverlayMessage()
}
```

### Tour Statistics

```swift
let stats = tourCoordinator.getTourStats(.socialNavigationDemo)
print("Status: \(stats.status)")
print("Completed: \(stats.isCompleted)")
print("Seen steps: \(stats.seenStepsCount)")

let allStats = tourCoordinator.getAllTourStats()
for stat in allStats {
    print("\(stat.tourType): \(stat.status)")
}
```

### Reset Tours

```swift
tourCoordinator.resetTour(.socialNavigationDemo)

let persistence = TourPersistence()
persistence.resetAllTours()
```

## Features

### Spotlight System
- Dimmed background overlay (70% opacity)
- Highlighted target element w/ customizable shape
- Pulse animation on spotlight
- Gesture blocking outside spotlight
- Smooth fade-in/out transitions

### Persistence
- UserDefaults-based storage
- Tracks completed tours w/ completion dates
- Tracks individual seen steps
- "Don't show again" option
- Tour skip tracking
- Reset functionality for testing

### Tour Actions
- `NavigateToSocialAction`: Navigate to social tab
- `NavigateToMapAction`: Navigate to map tab
- `EnableDrawingModeAction`: Enable map drawing
- `DisableDrawingModeAction`: Disable map drawing
- `HighlightElementAction`: Highlight specific element
- `ShowOverlayAction`: Show temporary message

### Predefined Tours

**Social Navigation Demo** (6 steps)
1. Social features intro
2. Friends tab
3. Events tab
4. Group walks tab
5. Chats tab
6. Lost dogs alert

**Field Drawing Demo** (5 steps)
1. Drawing intro
2. Enable drawing mode
3. Add points
4. Complete drawing
5. Delete fields

**Map Features Demo** (4 steps)
1. Search button
2. Filter button
3. Location button
4. Start walk button

## Architecture Notes

### State Management
- `TourCoordinator` is `@MainActor` to ensure UI updates on main thread
- Uses `@Published` properties for reactive UI updates
- Combine framework for state observation

### View Modifiers
- `.tourOverlay(coordinator:)`: Apply tour UI to entire view hierarchy
- `.tourTarget(id:coordinator:)`: Mark individual UI elements
- GeometryReader + PreferenceKey for frame tracking

### Spotlight Effect
- Uses `.blendMode(.destinationOut)` for cutout effect (iOS 15+)
- Alternative: Shape masking for iOS 14 compatibility
- Pulse animation: 1.5s ease-in-out repeat

### Persistence Keys
- `tour_completed_<TOUR_TYPE>`: Completion flag
- `tour_completed_<TOUR_TYPE>_date`: Completion timestamp
- `step_seen_<TOUR_TYPE>_<STEP_ID>`: Step seen flag
- `tour_completed_<TOUR_TYPE>_skipped`: Skip flag
- `tour_completed_<TOUR_TYPE>_dont_show`: Don't show again flag

## Testing

```swift
let coordinator = TourCoordinator(userDefaults: .standard)

coordinator.resetTour(.socialNavigationDemo)
coordinator.startTour(.socialNavigationDemo)

assert(coordinator.isTourActive() == true)
assert(coordinator.getCurrentStep()?.id == "social_intro")

coordinator.nextStep()
assert(coordinator.getCurrentStep()?.id == "social_friends")

coordinator.skipTour()
assert(coordinator.isTourActive() == false)
assert(coordinator.getTourStats(.socialNavigationDemo).isSkipped == true)
```

## Future Enhancements

- Interactive tour builder UI
- Analytics integration (step completion rates, skip points)
- A/B testing different tour flows
- Video/GIF support in tour steps
- Multi-language support
- Tour branching based on user actions
- Tour scheduling (show after X days, Y app launches)
