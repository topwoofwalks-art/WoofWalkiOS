# iOS Location Services Configuration

## Required Info.plist Keys

Add these keys to your Info.plist file to enable location services:

### Privacy Descriptions (Required by Apple)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>WoofWalk needs your location to track your dog walks and show nearby dog-friendly places</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>WoofWalk needs your location always to track walks in the background and notify you of nearby dog parks</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>WoofWalk needs your location always to track walks in the background</string>
```

### Background Modes

Enable background location updates in your app's Capabilities or add to Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

## Authorization Levels

### When In Use
- Location updates only when app is in foreground
- Suitable for: Viewing current location, searching nearby places

### Always
- Location updates in background
- Suitable for: Walk tracking, geofencing, background notifications
- Required for: Full walk tracking functionality

## Implementation

### Request Authorization

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var locationService = LocationService.shared

    var body: some View {
        VStack {
            switch locationService.authorizationStatus {
            case .notDetermined:
                Button("Enable Location") {
                    locationService.requestWhenInUseAuthorization()
                }
            case .authorizedWhenInUse:
                Button("Enable Background Tracking") {
                    locationService.requestAlwaysAuthorization()
                }
            case .authorizedAlways:
                Text("Location enabled")
            case .denied, .restricted:
                Text("Location access denied. Enable in Settings.")
            }
        }
    }
}
```

### Start Tracking Walk

```swift
let walkTrackingService = WalkTrackingService.shared

// Start tracking
walkTrackingService.startTracking()

// Observe updates
walkTrackingService.$trackingState
    .sink { state in
        print("Distance: \(state.distanceMeters)m")
        print("Duration: \(state.durationSeconds)s")
        print("Pace: \(state.currentPaceKmh) km/h")
    }
    .store(in: &cancellables)

// Stop tracking
let walkHistory = walkTrackingService.stopTracking()
```

### Get Current Location

```swift
let locationService = LocationService.shared

// Async/await
Task {
    do {
        let coordinate = try await locationService.getCurrentLocation()
        print("Current location: \(coordinate)")
    } catch {
        print("Location error: \(error)")
    }
}

// Publisher
locationService.locationUpdatePublisher
    .sink { update in
        print("Location update: \(update.coordinate)")
    }
    .store(in: &cancellables)
```

### Geofencing (Region Monitoring)

```swift
let locationService = LocationService.shared

// Create circular region
let region = CLCircularRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    radius: 100,
    identifier: "dog_park_123"
)
region.notifyOnEntry = true
region.notifyOnExit = true

// Start monitoring
locationService.startMonitoring(region: region)

// Listen for region events
NotificationCenter.default.addObserver(
    forName: .didEnterRegion,
    object: nil,
    queue: .main
) { notification in
    if let region = notification.userInfo?["region"] as? CLRegion {
        print("Entered region: \(region.identifier)")
    }
}
```

### Significant Location Changes

For battery-efficient background tracking:

```swift
locationService.startMonitoringSignificantLocationChanges()
```

## Battery Optimization

### Adjust Accuracy Based on Need

```swift
// High accuracy for active walk tracking
locationService.startUpdatingLocation(
    accuracy: kCLLocationAccuracyBest,
    distanceFilter: kCLDistanceFilterNone
)

// Lower accuracy for general location
locationService.startUpdatingLocation(
    accuracy: kCLLocationAccuracyHundredMeters,
    distanceFilter: 100
)
```

### Use Distance Filter

```swift
// Only get updates when user moves 10 meters
locationService.startUpdatingLocation(
    accuracy: kCLLocationAccuracyBest,
    distanceFilter: 10
)
```

### Stop When Not Needed

```swift
// Stop location updates when walk ends
walkTrackingService.stopTracking()
locationService.stopUpdatingLocation()
```

## Features Ported from Android

### From LocationProvider.kt
- getCurrentLocation() with timeout
- getLastKnownLocation()
- Result-based error handling

### From WalkTrackingService.kt
- High-accuracy location tracking (500ms updates)
- Distance calculation (Haversine formula)
- Speed & pace calculation
- Elevation gain tracking
- GPS quality assessment
- Auto-pause detection
- Milestone notifications
- Polyline encoding
- Calorie estimation
- Background tracking

### From MapViewModel.kt
- Distance calculation between points
- Camera position tracking
- User location updates
- Geofence management

## GPS Quality Levels

```swift
enum GPSQuality {
    case excellent  // < 10m accuracy
    case good       // 10-20m accuracy
    case fair       // 20-50m accuracy
    case poor       // > 50m accuracy
    case unknown
}
```

## Walk Tracking State

```swift
struct TrackingState {
    var isTracking: Bool
    var isPaused: Bool
    var distanceMeters: Double
    var durationSeconds: Int
    var currentPaceKmh: Double
    var currentSpeedMps: Double
    var polyline: [CLLocationCoordinate2D]
    var gpsAccuracy: CLLocationAccuracy
    var gpsQuality: GPSQuality
    var lastMilestoneKm: Int
    var caloriesBurned: Int
    var currentBearing: CLLocationDirection
    var elevationGainMeters: Double
}
```

## Notifications Required

Add notification capabilities for walk tracking features:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>remote-notification</string>
</array>
```

Request notification permission:

```swift
import UserNotifications

UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge]
) { granted, error in
    if granted {
        print("Notification permission granted")
    }
}
```

## Testing Location Services

### Simulator

In Xcode Simulator:
1. Debug > Location > Custom Location
2. Enter coordinates to simulate location
3. Use "Freeway Drive" or "City Run" for walk simulation

### Physical Device

Enable "Developer Mode" in Settings:
1. Settings > Privacy & Security > Developer Mode
2. Restart device
3. Use GPX files in Xcode for route simulation

## Performance Tips

1. **Use significant location changes** for background tracking when high accuracy isn't needed
2. **Set appropriate distance filters** to reduce battery usage
3. **Stop location updates** when app is backgrounded and tracking isn't active
4. **Filter by accuracy** - ignore updates with accuracy > 50m
5. **Debounce updates** - use 300ms debounce for UI updates
6. **Region monitoring** - use geofencing instead of continuous tracking when possible

## Common Issues

### Location Not Updating
- Check authorization status
- Verify Info.plist keys are present
- Ensure location services enabled in Settings
- Check if simulator location is set

### Background Tracking Not Working
- Request "Always" authorization
- Enable "location" background mode
- Ensure app doesn't suspend location manager
- Use `allowsBackgroundLocationUpdates = true`

### Poor Accuracy
- Move outdoors
- Avoid tall buildings
- Wait for GPS warm-up (30-60 seconds)
- Check for metal/concrete interference

## Migration from Android

| Android | iOS |
|---------|-----|
| FusedLocationProviderClient | CLLocationManager |
| LocationRequest | desiredAccuracy + distanceFilter |
| LocationCallback | CLLocationManagerDelegate |
| Priority.PRIORITY_HIGH_ACCURACY | kCLLocationAccuracyBest |
| requestLocationUpdates() | startUpdatingLocation() |
| GeofencingClient | startMonitoring(region:) |
| Geofence | CLCircularRegion |

## Resources

- [Apple Location and Maps Programming Guide](https://developer.apple.com/documentation/corelocation)
- [Background Execution](https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background)
- [Energy Efficiency Guide](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)
