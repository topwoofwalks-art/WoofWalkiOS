# Quick Start - iOS Location Services

## 1. Add Files to Xcode Project

Drag these files into your Xcode project:

```
WoofWalk/Services/
├── LocationService.swift
├── LocationPublisher.swift
├── WalkTrackingService.swift
└── GeofenceManager.swift
```

## 2. Configure Info.plist

Add these keys to Info.plist (or use "Info" tab in Xcode):

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>WoofWalk needs your location to track walks and show nearby places</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>WoofWalk needs background location to track walks</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

## 3. Enable Background Modes

In Xcode:
1. Select project target
2. Go to "Signing & Capabilities" tab
3. Click "+ Capability"
4. Add "Background Modes"
5. Check "Location updates"

## 4. Request Permissions

In your main view:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var locationService = LocationService.shared

    var body: some View {
        VStack {
            Button("Enable Location") {
                locationService.requestWhenInUseAuthorization()
            }

            Button("Enable Background Tracking") {
                locationService.requestAlwaysAuthorization()
            }
        }
    }
}
```

## 5. Track a Walk

```swift
import SwiftUI

struct WalkView: View {
    @StateObject private var walkService = WalkTrackingService.shared

    var body: some View {
        VStack {
            Text("\(walkService.trackingState.distanceMeters / 1000, specifier: "%.2f") km")
            Text("\(formatTime(walkService.trackingState.durationSeconds))")

            HStack {
                Button("Start") { walkService.startTracking() }
                Button("Pause") { walkService.pauseTracking() }
                Button("Stop") {
                    if let walk = walkService.stopTracking() {
                        saveWalk(walk)
                    }
                }
            }
        }
    }

    func formatTime(_ sec: Int) -> String {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    func saveWalk(_ walk: WalkHistory) {
        print("Walk saved: \(walk.distanceKm)km in \(walk.formattedDuration)")
    }
}
```

## 6. Get Current Location

```swift
Task {
    do {
        let location = try await LocationService.shared.getCurrentLocation()
        print("Current: \(location)")
    } catch {
        print("Error: \(error)")
    }
}
```

## 7. Setup Geofences

```swift
let geofence = GeofenceManager.shared

// Single geofence
geofence.registerGeofence(
    identifier: "dog_park",
    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    radius: 100
)

// Listen for entry
NotificationCenter.default.addObserver(
    forName: .didEnterRegion,
    object: nil,
    queue: .main
) { notification in
    print("Entered geofence!")
}
```

## 8. Testing

### Simulator
1. Run app in simulator
2. Debug > Location > Custom Location
3. Enter: 37.7749, -122.4194
4. Or use: Debug > Location > City Run

### Device
1. Build to physical device
2. Go outside for GPS signal
3. Start walk tracking
4. Walk around to generate data

## Common Issues

### "Location Not Updating"
- Check authorization status
- Verify Info.plist keys added
- Enable location in Settings > Privacy

### "Background Tracking Not Working"
- Request "Always" authorization
- Enable "location" background mode
- Check Info.plist for Always usage description

### "Poor GPS Accuracy"
- Move outdoors
- Wait 30-60 seconds for GPS warm-up
- Avoid tall buildings/metal structures

## Architecture

```
LocationService (Singleton)
    ├─> CLLocationManager wrapper
    ├─> Authorization management
    ├─> Location/heading updates
    └─> Region monitoring

LocationPublisher
    ├─> Combine publishers
    ├─> Filtered updates
    └─> Debounced streams

WalkTrackingService (Singleton)
    ├─> Walk tracking logic
    ├─> Distance/pace calculation
    ├─> Auto-pause detection
    └─> Milestone notifications

GeofenceManager (Singleton)
    ├─> Region monitoring
    ├─> POI geofencing
    └─> Entry/exit events
```

## Key Classes

| Class | Purpose |
|-------|---------|
| LocationService | Core location management |
| LocationPublisher | Combine publishers & filtering |
| WalkTrackingService | Walk tracking & metrics |
| GeofenceManager | Region monitoring |
| TrackingState | Observable walk state |
| WalkHistory | Completed walk data |

## Utilities

| Utility | Purpose |
|---------|---------|
| SpeedETACalculator | Pace, speed, ETA calculations |
| PolylineEncoder | Encode/decode polylines |
| GPSQuality | GPS accuracy levels |
| LocationUpdate | Location update model |
| TrackPoint | Walk track point |

## Next Steps

1. Import files to Xcode
2. Configure Info.plist
3. Enable background modes
4. Build and test on device
5. Integrate with existing ViewModels
6. Test walk tracking outdoors
7. Verify background tracking works

## Full Documentation

See detailed docs:
- LocationServicesConfig.md - Complete setup guide
- LOCATION_SERVICES_SUMMARY.md - Full implementation details

## Support

For detailed setup and troubleshooting, see:
- `/mnt/c/app/WoofWalkiOS/WoofWalk/Services/LocationServicesConfig.md`
- `/mnt/c/app/WoofWalkiOS/LOCATION_SERVICES_SUMMARY.md`
