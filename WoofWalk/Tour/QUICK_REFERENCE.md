# Tour System - Quick Reference Guide

## Component Overview

### Core Files
- **TourModels.swift** - Data models and enums
- **TourCoordinator.swift** - State management
- **TourSpotlightView.swift** - Spotlight highlighting system
- **TourOverlay.swift** - Full-screen tour overlay
- **InstructionCard.swift** - Tour step instruction card

### Demo Tours
- **MapTourDemo.swift** - 13-step map feature tour
- **LivestockFieldTourDemo.swift** - 9-step field drawing tour

---

## Common Tasks

### 1. Start a Built-in Tour

```swift
@StateObject private var tourCoordinator = TourCoordinator()

// In your view's onAppear
.onAppear {
    if tourCoordinator.shouldShowTour(.mapFeaturesDemo) {
        tourCoordinator.startTour(.mapFeaturesDemo)
    }
}
```

### 2. Add Tour Overlay to View

```swift
struct MyView: View {
    @StateObject private var tourCoordinator = TourCoordinator()
    
    var body: some View {
        ZStack {
            // Your content
        }
        .tourOverlay(coordinator: tourCoordinator)
    }
}
```

### 3. Mark Element as Tour Target

```swift
Button("Start Walk") {
    // action
}
.tourTarget(id: "start_walk_button", coordinator: tourCoordinator)
```

### 4. Create Custom Tour

```swift
let steps = [
    TourStep(
        id: "step1",
        title: "Welcome",
        description: "This is the first step",
        targetViewId: "button_1",
        position: .center
    ),
    TourStep(
        id: "step2",
        title: "Next Feature",
        description: "Learn about this feature",
        targetViewId: "button_2",
        position: .topRight1
    )
]

tourCoordinator.registerCustomTour(.custom, steps: steps)
tourCoordinator.startTour(.custom)
```

### 5. Reset Tour for Testing

```swift
// Reset specific tour
tourCoordinator.resetTour(.mapFeaturesDemo)

// Reset all tours
tourCoordinator.resetTour(.initialWalkthrough)
tourCoordinator.resetTour(.socialNavigationDemo)
tourCoordinator.resetTour(.fieldDrawingDemo)
tourCoordinator.resetTour(.mapFeaturesDemo)
```

### 6. Add Spotlight to Element

```swift
Button("Important") {
    // action
}
.tourSpotlight(
    id: "important_button",
    isHighlighted: tourCoordinator.currentStep?.targetViewId == "important_button",
    shape: .circle
)
```

---

## Tour Types

```swift
enum TourType {
    case initialWalkthrough      // First-time user onboarding
    case socialNavigationDemo    // Social features (6 steps)
    case fieldDrawingDemo        // Livestock field drawing (5 steps)
    case mapFeaturesDemo         // Map controls (4 steps)
    case custom                  // Your custom tour
}
```

---

## Spotlight Positions

```swift
enum SpotlightPosition {
    case topLeft           // Top-left corner
    case topRight1         // Top-right, first button
    case topRight2         // Top-right, second button
    case topRight3         // Top-right, third button
    case bottomNavSocial   // Bottom navigation social tab
    case bottomRight1      // Bottom-right, first button
    case bottomRight2      // Bottom-right, second button
    case bottomRight3      // Bottom-right, third button
    case center            // Center of screen
}
```

---

## Spotlight Shapes

```swift
enum SpotlightShape {
    case circle                              // Circular highlight
    case rectangle                           // Rectangular highlight
    case roundedRectangle(cornerRadius: CGFloat)  // Rounded rectangle
}
```

---

## TourCoordinator Methods

### Navigation
```swift
coordinator.nextStep()           // Move to next step
coordinator.previousStep()       // Move to previous step
coordinator.skipTour()           // Skip entire tour
coordinator.completeTour()       // Complete tour
coordinator.pauseTour()          // Pause tour
coordinator.resumeTour()         // Resume paused tour
```

### State Queries
```swift
coordinator.isTourActive()       // Is tour running?
coordinator.getCurrentStep()     // Get current step
coordinator.getTourProgress()    // Get progress info
coordinator.shouldShowTour(.mapFeaturesDemo)  // Should show?
```

### Highlights & Annotations
```swift
coordinator.highlightElement(targetElement: "btn", position: point)
coordinator.clearHighlight()
coordinator.addAnnotation(annotation)
coordinator.removeAnnotation(id: "anno1")
coordinator.clearAnnotations()
```

### Overlay Messages
```swift
coordinator.showOverlayMessage("Tip: Try this!")
coordinator.hideOverlayMessage()
```

### Callbacks
```swift
coordinator.setOnStepChangeCallback { step in
    print("Changed to: \(step.title)")
}

coordinator.setOnTourCompleteCallback { tourType in
    print("Completed: \(tourType)")
}

coordinator.setOnTourSkipCallback { tourType in
    print("Skipped: \(tourType)")
}
```

---

## Demo Tour Details

### MapTourDemo (13 Steps)

```swift
MapTourDemo(
    onComplete: {
        // Tour finished
    },
    onSkip: {
        // User skipped
    }
)
```

**Steps:**
1. Welcome screen
2. Zoom controls
3. My location button
4. Search button
5. Filter button
6. POI markers explanation
7. Add new place (long press)
8. Start walk button
9. Random walk feature
10. Route preview
11. Walking mode
12. Navigation guidance
13. Walk completion stats

### LivestockFieldTourDemo (9 Steps)

```swift
LivestockFieldTourDemo(
    onComplete: {
        // Tour finished
    },
    onSkip: {
        // User skipped
    }
)
```

**Steps:**
1. Introduction to livestock fields
2. Find the livestock button (highlighted)
3. View existing fields
4. Enable drawing mode (1 point animates in)
5. Add vertices (animates to 3 points)
6. Close polygon (animates to 5 points)
7. Select species (dialog appears)
8. Mark as hazardous (cattle + hazard selected)
9. Submit field (green completed field shown)

---

## Common Patterns

### Show Tour on First Launch
```swift
.onAppear {
    if tourCoordinator.shouldShowTour(.mapFeaturesDemo) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            tourCoordinator.startTour(.mapFeaturesDemo)
        }
    }
}
```

### Progressive Tours
```swift
// Show map tour first
if tourCoordinator.shouldShowTour(.mapFeaturesDemo) {
    tourCoordinator.setOnTourCompleteCallback { _ in
        // Then show field drawing tour
        if tourCoordinator.shouldShowTour(.fieldDrawingDemo) {
            tourCoordinator.startTour(.fieldDrawingDemo)
        }
    }
    tourCoordinator.startTour(.mapFeaturesDemo)
}
```

### Conditional Steps
```swift
var steps = baseTourSteps

if userHasPremium {
    steps.append(premiumFeatureStep)
}

tourCoordinator.registerCustomTour(.custom, steps: steps)
tourCoordinator.startTour(.custom)
```

---

## Debugging

### View Tour State
```swift
Text("Tour Active: \(tourCoordinator.isTourActive())")
Text("Current Step: \(tourCoordinator.getCurrentStep()?.title ?? "None")")
if let progress = tourCoordinator.getTourProgress() {
    Text("Step \(progress.currentStepIndex + 1) of \(progress.totalSteps)")
}
```

### Force Show Tours
```swift
// Even if already shown
tourCoordinator.resetTour(.mapFeaturesDemo)
tourCoordinator.startTour(.mapFeaturesDemo)
```

### Preview Individual Steps
```swift
struct TourStepPreview: PreviewProvider {
    static var previews: some View {
        InstructionCard(
            title: "Test Step",
            description: "Testing the card",
            position: .center,
            stepNumber: 1,
            totalSteps: 5,
            onNext: {},
            onPrevious: nil,
            onSkip: {}
        )
    }
}
```

---

## Best Practices

1. **Delay Tour Start**: Give UI time to render
   ```swift
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
       tourCoordinator.startTour(.mapFeaturesDemo)
   }
   ```

2. **Use Meaningful IDs**: Make tour target IDs descriptive
   ```swift
   .tourTarget(id: "start_walk_button", coordinator: coordinator)
   // NOT: .tourTarget(id: "btn1", coordinator: coordinator)
   ```

3. **Keep Steps Focused**: 1 feature per step, 5-7 words per title

4. **Test All Flows**: Test Next, Back, Skip, and Complete paths

5. **Handle State Changes**: Reset tour if user navigates away
   ```swift
   .onDisappear {
       if tourCoordinator.isTourActive() {
           tourCoordinator.pauseTour()
       }
   }
   ```

6. **Provide Skip Option**: Always allow users to exit

7. **Track Analytics**: Monitor completion rates
   ```swift
   coordinator.setOnTourCompleteCallback { tourType in
       Analytics.track("tour_completed", properties: ["type": tourType])
   }
   ```

---

## Troubleshooting

### Tour Not Showing
- Check `shouldShowTour()` returns true
- Verify `.tourOverlay()` is applied to view
- Ensure coordinator is `@StateObject`, not `@State`

### Spotlight Not Highlighting
- Verify `.tourTarget(id:)` is applied to element
- Check target ID matches `step.targetViewId`
- Ensure element is visible when step shows

### Animations Not Working
- Check view is in view hierarchy when tour starts
- Verify no conflicting animations
- Use `.animation(.default)` on tour overlay

### Steps Skipping
- Verify step count matches array length
- Check `currentStepIndex` bounds
- Ensure `nextStep()` logic is correct

---

## Performance Tips

1. Use `@StateObject` for coordinator (not `@ObservedObject` at root)
2. Lazy-load demo tours (don't create unless needed)
3. Clear tour state when done: `clearTour()`
4. Limit animation complexity on low-end devices
5. Use `.drawingGroup()` for complex Canvas drawings

---

*Quick reference for WoofWalk iOS tour system*
*Last updated: 2025-11-01*
