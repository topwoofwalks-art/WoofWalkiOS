# Navigation Models & Logic

Ported from Android: `com.woofwalk.ui.map.GuidanceViewModel`

## Models

### 1. GuidanceState (Enum with Associated Values)
State machine for navigation guidance:
- `idle`: No active navigation
- `active(ActiveGuidance)`: Turn-by-turn navigation in progress
- `offRoute(OffRouteGuidance)`: User deviated >30m from route
- `completed`: Navigation finished
- `error(String)`: Navigation error occurred

### 2. ActiveGuidance
Current navigation state:
- `currentInstruction`: HTML-formatted turn instruction
- `distanceToNextStepMeters`: Distance to next maneuver
- `currentStepIndex`: Current step (0-indexed)
- `totalSteps`: Total steps in route
- `routePolyline`: Full route coordinates
- `remainingDistanceMeters`: Total distance remaining
- `estimatedTimeRemainingSeconds`: ETA to destination
- `isRerouting`: Reroute in progress

### 3. OffRouteGuidance
Off-route state:
- `distanceOffRoute`: How far off route (meters)
- `lastKnownGuidance`: Last valid navigation state

### 4. RouteStep
Individual navigation instruction:
- `instruction`: HTML turn instruction
- `distance`: Step distance (meters)
- `duration`: Step duration (seconds)
- `startLocation`: Step start coordinate
- `endLocation`: Step end coordinate
- `maneuver`: Optional maneuver type
- `polyline`: Encoded polyline for step

### 5. NavigationProgress
Progress tracking:
- `currentStepIndex`: Current step index
- `distanceToNextStep`: Distance to next step
- `totalDistanceRemaining`: Total remaining distance
- `totalTimeRemaining`: Total remaining time
- `percentComplete`: Progress percentage (0-100)

### 6. Route
Complete route model:
- `summary`: Route summary text
- `polyline`: Encoded polyline string
- `legs`: Array of RouteLeg
- `warnings`: Route warnings
- `bounds`: Route bounding box
- Computed: `totalDistance`, `totalDuration`, `allSteps`, `decodedPolyline`

## Core Algorithms

### Distance Calculation (Haversine Formula)
```swift
NavigationLogic.calculateDistance(from: coord1, to: coord2) -> Double
```
- Uses Haversine formula for spherical distance
- Returns meters between two coordinates
- Earth radius: 6,371,000 meters

### Distance to Polyline
```swift
NavigationLogic.calculateDistanceToPolyline(point: coord, polyline: [coord]) -> Double
```
- Calculates shortest distance from point to polyline
- Iterates through all line segments
- Uses perpendicular projection to segment

### Distance to Line Segment
```swift
NavigationLogic.distanceToLineSegment(point: coord, lineStart: coord, lineEnd: coord) -> Double
```
- Projects point onto line segment
- Calculates parameter t (0-1) for closest point
- Handles edge cases (t<0, t>1)

### Off-Route Detection
```swift
NavigationLogic.isOffRoute(userLocation: coord, polyline: [coord]) -> Bool
```
- Threshold: 30 meters
- Returns true if user >30m from any route segment
- Triggers reroute request

### Step Advancement
```swift
NavigationLogic.shouldAdvanceToNextStep(userLocation: coord, stepEndLocation: coord) -> Bool
```
- Threshold: 15 meters
- Returns true when within 15m of step end
- Advances to next instruction

### ETA Calculation
```swift
NavigationLogic.calculateETA(distanceMeters: Double, averageSpeedMps: Double = 1.4) -> TimeInterval
```
- Default walking speed: 1.4 m/s (5 km/h)
- Returns estimated time to destination
- Used for remaining time calculations

### Bearing Calculation
```swift
NavigationLogic.calculateBearing(from: coord, to: coord) -> Double
```
- Returns bearing in degrees (0-360)
- 0° = North, 90° = East, 180° = South, 270° = West
- Used for direction indication

### Polyline Encoding/Decoding
```swift
NavigationLogic.decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D]
NavigationLogic.encodePolyline(_ coordinates: [CLLocationCoordinate2D]) -> String
```
- Google Polyline Algorithm Format 5
- Variable-length encoding
- Precision: 5 decimal places (1E5)

### HTML Instruction Cleaning
```swift
NavigationLogic.cleanHtmlInstruction(_ html: String) -> String
```
- Removes `<b>`, `</b>`, `<div>`, `</div>` tags
- Replaces `&nbsp;` with space
- Trims whitespace

## Usage Example

```swift
class MapViewModel: ObservableObject {
    @Published var navigationManager = NavigationManager()

    func startNavigation(route: Route, userLocation: CLLocationCoordinate2D) {
        navigationManager.startGuidance(route: route, userLocation: userLocation)
    }

    func onLocationUpdate(_ location: CLLocation) {
        navigationManager.trackProgress(userLocation: location.coordinate)

        // Handle off-route
        if navigationManager.shouldRequestReroute {
            Task {
                await navigationManager.requestReroute(from: location.coordinate)
                // Fetch new route from API
                // navigationManager.updateWithNewRoute(newRoute, userLocation: location.coordinate)
            }
        }

        // Handle completion
        if case .completed = navigationManager.guidanceState {
            onNavigationComplete()
        }
    }

    func stopNavigation() {
        navigationManager.stopGuidance()
    }
}
```

## Key Constants

- **Off-Route Threshold**: 30.0 meters
- **Step Completion Threshold**: 15.0 meters
- **Earth Radius**: 6,371,000 meters
- **Default Walking Speed**: 1.4 m/s (5 km/h)

## State Transitions

```
idle → active: startGuidance()
active → active: trackProgress() (normal progress)
active → offRoute: trackProgress() (distance > 30m)
active → completed: trackProgress() (last step reached)
active → error: invalid data
offRoute → active: updateWithNewRoute()
* → idle: stopGuidance()
```

## Thread Safety

- `NavigationManager` is marked `@MainActor`
- All state updates occur on main thread
- Safe for SwiftUI `@Published` properties
- Location updates should be dispatched to main thread

## Testing Considerations

1. **Distance Calculation**: Test with known coordinates and expected distances
2. **Off-Route Detection**: Test with points inside/outside threshold
3. **Step Advancement**: Test with locations near/far from step end
4. **Polyline Decode**: Verify against Google Maps polyline examples
5. **State Transitions**: Test all state machine paths
6. **Edge Cases**: Empty steps, single step, invalid coordinates
