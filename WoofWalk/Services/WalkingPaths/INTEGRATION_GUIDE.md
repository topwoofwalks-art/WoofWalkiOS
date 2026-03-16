# Walking Paths Integration Guide

Step-by-step guide to integrate walking paths into your existing WoofWalk map.

## 1. Add to Xcode Project

Add these files to your Xcode project under `Services/WalkingPaths/`:
- WalkingPath.swift
- WalkingPathRepository.swift
- WalkingPathViewModel.swift
- WalkingPathOverlay.swift
- WalkingPathRoutingExtension.swift

## 2. Update Map View

### Add ViewModel

```swift
import SwiftUI
import MapKit

struct YourMapView: View {
    @StateObject private var pathViewModel = WalkingPathViewModel()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        Map(coordinateRegion: $region)
            .overlay(
                // Add walking path overlay
                WalkingPathOverlay(paths: pathViewModel.uiState.paths)
            )
            .overlay(
                // Add path layer toggle and legend
                VStack {
                    Spacer()
                    HStack {
                        pathLayerControls
                        Spacer()
                        if pathViewModel.uiState.isPathLayerEnabled {
                            WalkingPathLegend()
                        }
                    }
                    .padding()
                }
            )
            .onChange(of: region) { newRegion in
                loadPathsForRegion(newRegion)
            }
            .onAppear {
                loadPathsForRegion(region)
            }
    }

    private var pathLayerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                pathViewModel.togglePathLayer()
                if pathViewModel.uiState.isPathLayerEnabled {
                    loadPathsForRegion(region)
                }
            }) {
                HStack {
                    Image(systemName: pathViewModel.uiState.isPathLayerEnabled
                        ? "map.fill"
                        : "map")
                    Text(pathViewModel.uiState.isPathLayerEnabled
                        ? "Hide Paths"
                        : "Show Paths")
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
            }

            if pathViewModel.uiState.isLoading {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
            }
        }
    }

    private func loadPathsForRegion(_ region: MKCoordinateRegion) {
        let bounds = [
            CLLocationCoordinate2D(
                latitude: region.center.latitude - region.span.latitudeDelta / 2,
                longitude: region.center.longitude - region.span.longitudeDelta / 2
            ),
            CLLocationCoordinate2D(
                latitude: region.center.latitude + region.span.latitudeDelta / 2,
                longitude: region.center.longitude + region.span.longitudeDelta / 2
            )
        ]

        pathViewModel.loadPathsInViewport(bounds: bounds)
    }
}
```

## 3. Integrate with Routing

### Enhanced Route Planning

```swift
class RouteManager {
    private let pathRepository = WalkingPathRepository.shared

    func planRoute(from start: CLLocationCoordinate2D,
                   to end: CLLocationCoordinate2D) async throws -> Route {

        // Find walking paths between points
        let paths = await pathRepository.findPathsForRouting(
            start: start,
            end: end,
            maxDetourMeters: 500.0
        )

        // Get pedestrian alternatives
        let alternative = await pathRepository.suggestPedestrianAlternatives(
            route: [start, end],
            preferPedestrian: true
        )

        // If high-quality paths available, inform user
        if let alt = alternative, alt.isWorthwhile {
            print("Suggestion: \(alt.description)")
            // Show user option to take better pedestrian path
        }

        // Build route with OSRM, preferring known paths
        let route = try await buildOSRMRoute(
            from: start,
            to: end,
            preferredPaths: paths
        )

        return route
    }
}
```

## 4. Path-Based Navigation

### Show Path Instructions

```swift
struct NavigationView: View {
    let segments: [PathSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(segments.indices, id: \.self) { index in
                HStack {
                    Image(systemName: segments[index].isOptimal
                        ? "checkmark.circle.fill"
                        : "circle")
                        .foregroundColor(segments[index].isOptimal ? .green : .gray)

                    VStack(alignment: .leading) {
                        Text(segments[index].description)
                            .font(.body)
                        Text(String(format: "%.0fm", segments[index].path.length))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}
```

## 5. Filter Paths by Quality

### Custom Path Filtering

```swift
extension WalkingPathRepository {
    func getHighQualityPaths(minScore: Double = 10.0) async -> [WalkingPath] {
        let allPaths = await getAllCachedPaths()
        return allPaths.filter { $0.qualityScore >= minScore }
    }

    func getAccessiblePaths() async -> [WalkingPath] {
        let allPaths = await getAllCachedPaths()
        return allPaths.filter { path in
            path.osmTags["wheelchair"] == "yes" ||
            path.osmTags["stroller"] == "yes"
        }
    }

    func getNamedPaths() async -> [WalkingPath] {
        let allPaths = await getAllCachedPaths()
        return allPaths.filter { $0.name != nil }
    }
}
```

## 6. Real-Time Path Updates

### Monitor Map Changes

```swift
struct MapViewWithPaths: View {
    @StateObject private var pathViewModel = WalkingPathViewModel()
    @State private var region = MKCoordinateRegion(/* ... */)
    @State private var lastUpdateTime = Date()

    var body: some View {
        Map(coordinateRegion: $region)
            .overlay(WalkingPathOverlay(paths: pathViewModel.uiState.paths))
            .onChange(of: region) { newRegion in
                // Throttle updates to avoid API spam
                let now = Date()
                if now.timeIntervalSince(lastUpdateTime) > 2.0 {
                    loadPathsForRegion(newRegion)
                    lastUpdateTime = now
                }
            }
    }
}
```

## 7. Performance Optimization

### Viewport-Based Loading

```swift
// Only load paths when viewport changes significantly
private func shouldUpdatePaths(oldRegion: MKCoordinateRegion,
                              newRegion: MKCoordinateRegion) -> Bool {
    let latChange = abs(oldRegion.center.latitude - newRegion.center.latitude)
    let lonChange = abs(oldRegion.center.longitude - newRegion.center.longitude)

    // Update if moved more than 50% of viewport
    return latChange > oldRegion.span.latitudeDelta * 0.5 ||
           lonChange > oldRegion.span.longitudeDelta * 0.5
}
```

### Cache Management

```swift
// Clear cache when app goes to background
.onReceive(NotificationCenter.default.publisher(
    for: UIApplication.didEnterBackgroundNotification
)) { _ in
    Task {
        await WalkingPathRepository.shared.clearCache()
    }
}
```

## 8. User Preferences

### Path Display Settings

```swift
struct PathPreferences {
    var showFootpaths = true
    var showCycleways = true
    var showSteps = false
    var showRoads = false
    var minQualityScore = 0.0
    var accessibleOnly = false
}

extension WalkingPathOverlay {
    func filtered(by prefs: PathPreferences) -> some View {
        let filteredPaths = paths.filter { path in
            guard path.qualityScore >= prefs.minQualityScore else { return false }

            if prefs.accessibleOnly {
                guard path.osmTags["wheelchair"] == "yes" ||
                      path.osmTags["stroller"] == "yes" else {
                    return false
                }
            }

            switch path.pathType {
            case .footway, .path, .pedestrian:
                return prefs.showFootpaths
            case .cycleway:
                return prefs.showCycleways
            case .steps:
                return prefs.showSteps
            case .residential, .service, .unclassified:
                return prefs.showRoads
            default:
                return false
            }
        }

        return WalkingPathOverlay(paths: filteredPaths)
    }
}
```

## 9. Testing

### Unit Tests

```swift
import XCTest
@testable import WoofWalk

class WalkingPathTests: XCTestCase {
    let repository = WalkingPathRepository.shared

    func testFetchPaths() async throws {
        let bounds = [
            CLLocationCoordinate2D(latitude: 51.5, longitude: -0.13),
            CLLocationCoordinate2D(latitude: 51.51, longitude: -0.12)
        ]

        let paths = try await repository.fetchWalkingPaths(bounds: bounds)
        XCTAssertGreaterThan(paths.count, 0)
    }

    func testQualityScore() {
        let path = WalkingPath(
            id: "test",
            pathType: .footway,
            coordinates: [],
            name: "Test Path",
            surface: "paved",
            length: 100.0,
            accessRestrictions: nil,
            osmTags: ["width": "3.0", "wheelchair": "yes"]
        )

        XCTAssertGreaterThan(path.qualityScore, 10.0)
    }
}
```

## 10. Error Handling

### Graceful Degradation

```swift
struct MapViewWithErrorHandling: View {
    @StateObject private var pathViewModel = WalkingPathViewModel()

    var body: some View {
        Map()
            .overlay(WalkingPathOverlay(paths: pathViewModel.uiState.paths))
            .alert(
                "Path Loading Error",
                isPresented: .constant(pathViewModel.uiState.error != nil)
            ) {
                Button("Retry") {
                    retryPathLoading()
                }
                Button("Dismiss") {
                    pathViewModel.clearError()
                }
            } message: {
                Text(pathViewModel.uiState.error ?? "Unknown error")
            }
    }
}
```

## Example: Complete Implementation

See the full example in the main README.md file for working code with all features integrated.

## Troubleshooting

### Paths Not Showing
1. Verify `isPathLayerEnabled` is true
2. Check console for API errors
3. Ensure bounds are valid
4. Check Overpass API status

### Performance Issues
1. Reduce viewport size
2. Increase update throttling
3. Limit path types shown
4. Clear cache periodically

### Wrong Path Data
1. Verify Overpass query syntax
2. Check OSM data quality in area
3. Ensure geometry is returned (`out geom`)
4. Validate coordinate parsing
