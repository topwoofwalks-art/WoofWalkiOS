# Tour Framework Architecture

## Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        App Layer                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         ContentView / RootView                      │   │
│  │  .environmentObject(tourCoordinator)                │   │
│  │  .tourOverlay(coordinator: tourCoordinator)         │   │
│  └───────────────────┬─────────────────────────────────┘   │
└────────────────────────┼───────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Tour Coordinator                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  @Published currentTour: TourProgress?               │  │
│  │  @Published highlightedElement: HighlightConfig?     │  │
│  │  @Published overlayMessage: String?                  │  │
│  │  @Published activeAnnotations: [TourAnnotation]      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Tour Lifecycle Methods                              │  │
│  │  • startTour(_ tourType: TourType)                   │  │
│  │  • nextStep()                                        │  │
│  │  • previousStep()                                    │  │
│  │  • pauseTour() / resumeTour()                        │  │
│  │  • skipTour() / completeTour()                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Tour Definitions (Predefined)                       │  │
│  │  • socialNavigationDemo (6 steps)                    │  │
│  │  • fieldDrawingDemo (5 steps)                        │  │
│  │  • mapFeaturesDemo (4 steps)                         │  │
│  │  • custom (dynamically registered)                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────┬───────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
┌─────────────────┐ ┌──────────┐ ┌─────────────────┐
│ TourPersistence │ │  Models  │ │ TourSpotlightView│
│                 │ │          │ │                  │
│ • UserDefaults  │ │ TourStep │ │ Overlay + UI     │
│ • Completion    │ │ TourType │ │ Spotlight Effect │
│ • Step Tracking │ │ TourState│ │ Pulse Animation  │
│ • Reset         │ │ Progress │ │ Tour Card        │
│ • Stats         │ │ Actions  │ │ Navigation       │
└─────────────────┘ └──────────┘ └─────────────────┘
```

## Data Flow

```
User Triggers Tour
       │
       ▼
TourCoordinator.startTour()
       │
       ├──> Create TourProgress
       │    └──> currentStepIndex = -1
       │
       ▼
TourCoordinator.nextStep()
       │
       ├──> Increment currentStepIndex
       ├──> Get TourStep from tourDefinitions
       ├──> Execute TourAction (if any)
       ├──> Update highlightedElement
       └──> Trigger onStepChangeCallback
              │
              ▼
       TourSpotlightView Observes State Change
              │
              ├──> Dim background (0.7 opacity)
              ├──> Render spotlight shape
              ├──> Start pulse animation
              └──> Show tour card w/ step info
                     │
                     ├──> User taps "Next"
                     ├──> User taps "Previous"
                     └──> User taps "Skip"
                            │
                            ▼
                   TourCoordinator handles action
                            │
                            ├──> nextStep() → Continue
                            ├──> previousStep() → Go back
                            └──> skipTour() → Mark skipped
                                   │
                                   ▼
                            TourPersistence.save()
                                   │
                                   └──> UserDefaults updated
```

## View Modifier Chain

```
ContentView()
    │
    ├──> .tourOverlay(coordinator:)
    │     │
    │     └──> Applies TourOverlayModifier
    │           │
    │           ├──> Wraps content in ZStack
    │           ├──> Observes coordinator.currentTour
    │           └──> Shows TourSpotlightView when active
    │
    └──> Child views...
          │
          ├──> Button("Action")
          │      └──> .tourTarget(id: "button_id", coordinator:)
          │            │
          │            └──> Applies TourTargetModifier
          │                  │
          │                  ├──> GeometryReader captures frame
          │                  ├──> Sets TourTargetPreferenceKey
          │                  └──> Updates coordinator.highlightedElement
          │
          └──> ...more views w/ .tourTarget()
```

## Spotlight Effect Rendering

```
TourSpotlightView
    │
    ├──> ZStack {
    │      │
    │      ├──> Color.black.opacity(0.7)  [Dimmed background]
    │      │
    │      ├──> Spotlight Shape (Circle/Rect/RoundedRect)
    │      │     │
    │      │     ├──> .fill(Color.clear)
    │      │     ├──> .stroke(Color.white, lineWidth: 2)
    │      │     ├──> .scaleEffect(pulseScale)  [1.0 → 1.1]
    │      │     ├──> .position(config.position)
    │      │     └──> .blendMode(.destinationOut)  [Cutout effect]
    │      │
    │      └──> Tour Card (VStack)
    │            │
    │            ├──> Title (Text)
    │            ├──> Description (Text)
    │            └──> HStack {
    │                  ├──> "Skip" Button
    │                  ├──> "Previous" Button
    │                  └──> "Next" Button
    │                }
    │     }
    │
    └──> .onAppear {
           ├──> Fade in dimmed background
           └──> Start pulse animation
         }
```

## Persistence Schema

```
UserDefaults Keys:

tour_shown_<TOUR_TYPE>
    ├──> Bool: true if tour shown
    └──> Ex: "tour_shown_SOCIAL_NAVIGATION_DEMO"

tour_completed_<TOUR_TYPE>
    ├──> Bool: true if completed
    └──> Ex: "tour_completed_SOCIAL_NAVIGATION_DEMO"

tour_completed_<TOUR_TYPE>_date
    ├──> Date: completion timestamp
    └──> Ex: "tour_completed_SOCIAL_NAVIGATION_DEMO_date"

step_seen_<TOUR_TYPE>_<STEP_ID>
    ├──> Bool: true if step seen
    └──> Ex: "step_seen_SOCIAL_NAVIGATION_DEMO_social_intro"

tour_completed_<TOUR_TYPE>_skipped
    ├──> Bool: true if skipped
    └──> Ex: "tour_completed_SOCIAL_NAVIGATION_DEMO_skipped"

tour_completed_<TOUR_TYPE>_dont_show
    ├──> Bool: true if user selected "don't show again"
    └──> Ex: "tour_completed_SOCIAL_NAVIGATION_DEMO_dont_show"

tutorial_completed
    └──> Bool: legacy initial walkthrough flag

tutorial_version
    └──> Int: tutorial version number
```

## State Machine

```
Tour State Machine:

    [Not Started] ──startTour()──> [In Progress]
                                         │
                                         ├──nextStep()──> [In Progress]
                                         │                 (next step)
                                         │
                                         ├──previousStep()──> [In Progress]
                                         │                    (prev step)
                                         │
                                         ├──pauseTour()──> [Paused]
                                         │                     │
                                         │                     └──resumeTour()──> [In Progress]
                                         │
                                         ├──skipTour()──> [Skipped] ──> [Clear State]
                                         │
                                         └──completeTour()──> [Completed] ──> [Clear State]

Clear State:
    • currentTour = nil
    • highlightedElement = nil
    • overlayMessage = nil
    • activeAnnotations = []
```

## GeometryReader + PreferenceKey Pattern

```
1. View w/ .tourTarget() modifier applied
        │
        ▼
2. TourTargetModifier wraps view
        │
        ├──> GeometryReader in background
        │      │
        │      └──> Captures view's frame in global coordinates
        │             │
        │             └──> Sets TourTargetPreferenceKey
        │                    value = [targetId: CGRect]
        │
        ▼
3. .onPreferenceChange(TourTargetPreferenceKey.self)
        │
        ├──> Receives [String: CGRect] dictionary
        ├──> Looks up current target ID
        └──> If match found:
               │
               ├──> Calculate center point
               ├──> Calculate radius
               └──> Update coordinator.highlightedElement
                      │
                      ▼
               TourSpotlightView re-renders w/ new position
```

## Callback Flow

```
TourCoordinator Methods:
    │
    ├──> setOnStepChangeCallback(_ callback:)
    │      │
    │      └──> Called when nextStep() or previousStep()
    │            Passes current TourStep
    │
    ├──> setOnTourCompleteCallback(_ callback:)
    │      │
    │      └──> Called when completeTour()
    │            Passes TourType
    │
    └──> setOnTourSkipCallback(_ callback:)
           │
           └──> Called when skipTour()
                 Passes TourType

Usage in App:
    │
    ├──> tourCoordinator.setOnStepChangeCallback { step in
    │       // Navigate, update UI, log analytics
    │    }
    │
    ├──> tourCoordinator.setOnTourCompleteCallback { tourType in
    │       // Show completion message, unlock features
    │    }
    │
    └──> tourCoordinator.setOnTourSkipCallback { tourType in
           // Log skip event, show alternative onboarding
        }
```

## Threading Model

```
@MainActor class TourCoordinator
    │
    ├──> All @Published properties update on main thread
    ├──> All public methods run on main actor
    └──> UI updates are thread-safe

SwiftUI View Updates:
    │
    ├──> @ObservedObject var coordinator: TourCoordinator
    ├──> Automatically subscribes to @Published changes
    └──> Re-renders on main thread when state changes

Persistence (UserDefaults):
    │
    ├──> Synchronous reads/writes
    ├──> Called from main thread
    └──> No concurrency issues
```

## Animation Timeline

```
Tour Start:
    0.0s: startTour() called
    0.0s: currentTour updated → triggers view update
    0.0s: TourSpotlightView appears
    0.0s: Dimmed background starts fade-in
    0.3s: Dimmed background fully visible (opacity 0.7)
    0.0s: Pulse animation starts (infinite loop)
    1.5s: Pulse animation completes one cycle
    ∞:    Animation repeats forever

Tour Step Change:
    0.0s: nextStep() or previousStep()
    0.0s: currentStepIndex updated
    0.0s: highlightedElement updated
    0.0s: View re-renders w/ new step
    0.0s: New pulse animation begins

Tour End:
    0.0s: skipTour() or completeTour()
    0.0s: State updated to .skipped or .completed
    0.0s: clearTour() called
    0.0s: TourSpotlightView disappears
    0.0s: Dimmed background fades out
```

## Error Handling

```
TourCoordinator Guards:

startTour():
    └──> guard !steps.isEmpty else { return }

nextStep():
    └──> guard let current = currentTour else { return }
    └──> guard let steps = tourDefinitions[current.tourType] else { return }
    └──> if nextIndex >= steps.count { completeTour() }

previousStep():
    └──> guard let current = currentTour else { return }
    └──> guard current.currentStepIndex > 0 else { return }

getCurrentStep():
    └──> guard let current = currentTour else { return nil }
    └──> guard let steps = tourDefinitions[current.tourType] else { return nil }
    └──> return steps.indices.contains(index) ? steps[index] : nil
```

## Memory Management

```
TourCoordinator:
    │
    ├──> @StateObject in App or root view
    │      └──> Single instance, retained for app lifetime
    │
    ├──> @EnvironmentObject in child views
    │      └──> Weak reference, no retain cycle
    │
    ├──> Callbacks use @escaping closures
    │      └──> Stored as instance variables
    │      └──> No [weak self] needed (coordinator is long-lived)
    │
    └──> UserDefaults is singleton
           └──> No memory leaks

TourSpotlightView:
    │
    ├──> Created/destroyed w/ tour state
    ├──> @State for animation values
    └──> Cleaned up when tour ends
```

## Extension Points

```
Custom Tour Actions:
    1. Create struct implementing TourAction protocol
    2. Implement execute() method
    3. Use in TourStep.action

Custom Spotlight Shapes:
    1. Add case to SpotlightShape enum
    2. Add rendering in TourSpotlightView.spotlightHighlight()

Custom Tour Types:
    1. Add case to TourType enum
    2. Register steps w/ registerCustomTour()
    3. Add persistence keys to TourPersistence

Custom Annotations:
    1. Add style to AnnotationStyle enum
    2. Define backgroundColor/textColor
    3. Use w/ addAnnotation()
```

---

**Architecture**: Clean separation | SwiftUI native | Type-safe | Thread-safe | Testable
**Patterns**: MVVM | Observer | State Machine | Coordinator | View Modifier
**Performance**: Lightweight | Efficient | Minimal overhead | Lazy loading support
