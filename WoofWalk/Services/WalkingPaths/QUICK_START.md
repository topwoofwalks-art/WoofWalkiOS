# Quick Start - Walking Paths System

Get walking paths running in your app in 5 minutes.

## 1. Add Files to Xcode (30 seconds)

In Xcode:
1. Right-click `Services` folder
2. Select "Add Files to WoofWalk..."
3. Select `WalkingPaths` folder
4. Check "Copy items if needed"
5. Click "Add"

## 2. Test Overpass Query (1 minute)

Open `WalkingPathRepository.swift` and verify it compiles:

```bash
# In your iOS project directory
swift build  # or just build in Xcode
```

## 3. Add to Map View (2 minutes)

Open your existing map view file and add:

```swift
import SwiftUI
import MapKit

struct YourMapView: View {
    @StateObject private var pathViewModel = WalkingPathViewModel()

    var body: some View {
        Map()
            .overlay(
                WalkingPathOverlay(paths: pathViewModel.uiState.paths)
            )
            .onAppear {
                pathViewModel.togglePathLayer()
                loadPaths()
            }
    }

    func loadPaths() {
        let bounds = [
            CLLocationCoordinate2D(latitude: 51.5, longitude: -0.13),
            CLLocationCoordinate2D(latitude: 51.51, longitude: -0.12)
        ]
        pathViewModel.loadPathsInViewport(bounds: bounds)
    }
}
```

## 4. Run and Test (1 minute)

1. Build and run (⌘R)
2. Map should show blue dashed lines for footpaths
3. Tap any path to see details
4. Check console for "[WALKING_PATHS]" logs

## 5. Verify It Works

Expected console output:
```
[WALKING_PATHS] Fetching paths in bounds: S=51.5, W=-0.13, N=51.51, E=-0.12
[WALKING_PATHS] Fetched 47 paths, total cached: 47
[PATH_LAYER] Loaded 47 paths
```

## Quick Test Locations

### London (Hyde Park)
```swift
CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
```

### New York (Central Park)
```swift
CLLocationCoordinate2D(latitude: 40.7829, longitude: -73.9654)
```

### San Francisco (Golden Gate Park)
```swift
CLLocationCoordinate2D(latitude: 37.7694, longitude: -122.4862)
```

## Toggle Button (Optional)

Add a button to show/hide paths:

```swift
Button(action: { pathViewModel.togglePathLayer() }) {
    HStack {
        Image(systemName: pathViewModel.uiState.isPathLayerEnabled ? "map.fill" : "map")
        Text(pathViewModel.uiState.isPathLayerEnabled ? "Hide Paths" : "Show Paths")
    }
}
```

## Common Issues

### No Paths Showing?
- Check console for errors
- Verify bounds are correct (south < north, west < east)
- Try different location (some areas have sparse OSM data)
- Ensure layer is enabled: `pathViewModel.uiState.isPathLayerEnabled == true`

### Map Crashes?
- Verify OverpassModels.swift was updated with geometry support
- Check that coordinates array is not empty
- Ensure you're on main thread for UI updates

### API Timeout?
- Reduce bounds size (smaller area)
- Check internet connection
- Verify Overpass API is online: https://overpass-api.de/api/status

## Next Steps

1. ✅ Paths showing? Great! Read [README.md](README.md) for features
2. Want routing integration? See [WalkingPathRoutingExtension.swift](WalkingPathRoutingExtension.swift)
3. Need examples? Check [OVERPASS_EXAMPLES.md](OVERPASS_EXAMPLES.md)
4. Full integration guide: [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)

## Example: Complete Minimal Implementation

```swift
import SwiftUI
import MapKit

struct WalkingPathsMapView: View {
    @StateObject private var viewModel = WalkingPathViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region)
                .overlay(
                    WalkingPathOverlay(paths: viewModel.uiState.paths)
                )

            VStack {
                Spacer()
                HStack {
                    Button(action: { viewModel.togglePathLayer() }) {
                        Text(viewModel.uiState.isPathLayerEnabled ? "Hide" : "Show")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.togglePathLayer()
            loadPaths()
        }
    }

    func loadPaths() {
        let bounds = [
            CLLocationCoordinate2D(
                latitude: region.center.latitude - 0.005,
                longitude: region.center.longitude - 0.005
            ),
            CLLocationCoordinate2D(
                latitude: region.center.latitude + 0.005,
                longitude: region.center.longitude + 0.005
            )
        ]
        viewModel.loadPathsInViewport(bounds: bounds)
    }
}

#Preview {
    WalkingPathsMapView()
}
```

Copy this entire struct into a new SwiftUI file and run it - paths should appear immediately!

## Performance Tips

For production use:

```swift
// Throttle map updates
@State private var lastUpdate = Date()

func loadPathsIfNeeded() {
    let now = Date()
    guard now.timeIntervalSince(lastUpdate) > 2.0 else { return }
    lastUpdate = now
    loadPaths()
}

// Call this instead of loadPaths() directly
.onChange(of: region) { _ in loadPathsIfNeeded() }
```

## Debug Mode

Enable detailed logging:

```swift
// In WalkingPathRepository.swift, change to:
print("[WALKING_PATHS] Detailed: \(element)")  // See all data

// In WalkingPathViewModel.swift:
print("[PATH_LAYER] State: \(uiState)")  // See full state
```

---

**You're done!** Walking paths should now be visible on your map.

For questions, see the comprehensive [README.md](README.md) or [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md).
