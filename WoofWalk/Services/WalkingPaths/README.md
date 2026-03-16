# Walking Paths System

Complete OSM-based walking path infrastructure for iOS with path quality scoring, routing integration, and map overlays.

## Architecture

### Components

1. **WalkingPath.swift** - Core model with 14 path types and quality scoring
2. **WalkingPathRepository.swift** - Actor-based repository with caching
3. **WalkingPathViewModel.swift** - SwiftUI view model for UI state
4. **WalkingPathOverlay.swift** - Map overlay rendering and path details
5. **WalkingPathRoutingExtension.swift** - Routing integration

## Path Types & Priority

```swift
enum PathType {
    case footway         // Priority: 1 (Best for pedestrians)
    case bridleway       // Priority: 1
    case path            // Priority: 2
    case pedestrian      // Priority: 2
    case track           // Priority: 3
    case cycleway        // Priority: 4
    case steps           // Priority: 5
    case livingStreet    // Priority: 6
    case unclassified    // Priority: 6
    case residential     // Priority: 7
    case service         // Priority: 8
    case tertiary        // Priority: 9
    case secondary       // Priority: 10
    case primary         // Priority: 11
    case unknown         // Priority: 12 (Worst)
}
```

## Quality Scoring

The system calculates a quality score for each path based on:

### Base Score
- Inverse of priority (13 - priority)
- Footway/Bridleway: 12 points
- Unknown paths: 1 point

### Surface Bonus
- Paved/Asphalt/Concrete: +2.0
- Gravel: +1.0

### Width Bonus
- >= 3.0m: +1.5
- >= 2.0m: +1.0

### Accessibility Bonus
- Wheelchair/Stroller friendly: +1.0

### Example Scores
- Premium footway (paved, 3m wide, wheelchair): 15.5
- Basic path (unpaved, no width info): 11.0
- Residential street: 6.0

## Overpass Query Examples

### Basic Walking Paths Query

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](51.5,-0.1,51.6,0.0);
  way["highway"="path"](51.5,-0.1,51.6,0.0);
  way["highway"="pedestrian"](51.5,-0.1,51.6,0.0);
);
out geom;
```

### Complete Path Network (14 types)

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](south,west,north,east);
  way["highway"="path"](south,west,north,east);
  way["highway"="track"](south,west,north,east);
  way["highway"="bridleway"](south,west,north,east);
  way["highway"="cycleway"](south,west,north,east);
  way["highway"="pedestrian"](south,west,north,east);
  way["highway"="steps"](south,west,north,east);
  way["highway"="unclassified"](south,west,north,east);
  way["highway"="residential"](south,west,north,east);
  way["highway"="service"](south,west,north,east);
  way["highway"="living_street"](south,west,north,east);
  way["highway"="tertiary"](south,west,north,east);
  way["highway"="secondary"](south,west,north,east);
  way["highway"="primary"](south,west,north,east);
);
out geom;
```

### Pedestrian Paths with Surface Info

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["surface"](south,west,north,east);
  way["highway"="path"]["surface"](south,west,north,east);
  way["highway"="pedestrian"]["surface"](south,west,north,east);
);
out geom;
```

### Accessible Paths (Wheelchair/Stroller)

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["wheelchair"="yes"](south,west,north,east);
  way["highway"="path"]["wheelchair"="yes"](south,west,north,east);
  way["highway"="footway"]["stroller"="yes"](south,west,north,east);
  way["highway"="path"]["stroller"="yes"](south,west,north,east);
);
out geom;
```

### Paths Near Point (Radius Search)

```javascript
[out:json][timeout:30];
(
  way(around:500,51.5074,-0.1278)["highway"="footway"];
  way(around:500,51.5074,-0.1278)["highway"="path"];
  way(around:500,51.5074,-0.1278)["highway"="pedestrian"];
);
out geom;
```

### Named Paths Only

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["name"](south,west,north,east);
  way["highway"="path"]["name"](south,west,north,east);
);
out geom;
```

## Usage Examples

### Basic Path Loading

```swift
let repository = WalkingPathRepository.shared

// Define viewport bounds
let bounds = [
    CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
    CLLocationCoordinate2D(latitude: 51.6, longitude: 0.0)
]

// Fetch paths
let paths = try await repository.fetchWalkingPaths(bounds: bounds)
print("Fetched \(paths.count) walking paths")
```

### Find Nearby Paths

```swift
let userLocation = CLLocationCoordinate2D(
    latitude: 51.5074,
    longitude: -0.1278
)

let nearbyPaths = await repository.findNearbyPaths(
    location: userLocation,
    radiusMeters: 500.0
)

// Paths are sorted by distance
for path in nearbyPaths {
    print("\(path.pathType.displayName): \(path.name ?? "Unnamed")")
}
```

### Routing Integration

```swift
let start = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
let end = CLLocationCoordinate2D(latitude: 51.5090, longitude: -0.1250)

// Find paths suitable for routing
let routingPaths = await repository.findPathsForRouting(
    start: start,
    end: end,
    maxDetourMeters: 500.0
)

// Use paths with OSRM for better routes
for path in routingPaths {
    print("Priority \(path.pathType.priority): \(path.pathType.displayName)")
}
```

### Using ViewModel in SwiftUI

```swift
struct MapView: View {
    @StateObject private var viewModel = WalkingPathViewModel()

    var body: some View {
        Map {
            // Your map content
        }
        .overlay(
            WalkingPathOverlay(paths: viewModel.uiState.paths)
        )
        .onAppear {
            viewModel.togglePathLayer()
        }
    }
}
```

### Get Path Quality Alternatives

```swift
let route = [
    CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
    CLLocationCoordinate2D(latitude: 51.5090, longitude: -0.1250)
]

if let alternative = await repository.suggestPedestrianAlternatives(
    route: route,
    preferPedestrian: true
) {
    print(alternative.description)
    // "Better pedestrian paths available (+45m) - Quality: 12.3"
}
```

## Map Integration

### Rendering Paths

The `WalkingPathOverlay` component renders paths with type-specific styling:

- **Footpaths**: Blue dashed (5,3)
- **Cycle Paths**: Green dashed (3,2)
- **Tracks**: Brown dashed (8,4)
- **Steps**: Purple dashed (2,2)
- **Roads**: Gray dashed (10,5)

### Interactive Features

Tap any path to show:
- Path type and name
- Length and surface
- Accessibility info (wheelchair, stroller, width)
- Quality score
- Access restrictions

## Performance

### Caching Strategy

- Actor-based thread-safe caching
- Viewport-based lazy loading
- Automatic cache clearing on layer toggle
- 30-minute TTL (configurable)

### Query Optimization

1. Bounding box queries only
2. Geometry included in response (`out geom`)
3. 30-second timeout
4. Parallel coordinate processing

### Memory Management

- Cached as dictionary for O(1) lookup
- Coordinate arrays (not MKPolyline) for cross-platform
- Lazy viewport filtering

## Distance Calculations

All distances use Haversine formula:

```swift
func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let earthRadius = 6371000.0 // meters
    let dLat = (to.latitude - from.latitude) * .pi / 180.0
    let dLon = (to.longitude - from.longitude) * .pi / 180.0

    let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(from.latitude * .pi / 180.0) * cos(to.latitude * .pi / 180.0) *
            sin(dLon / 2) * sin(dLon / 2)

    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earthRadius * c
}
```

## OSM Tag Reference

### Highway Types
- `footway`: Dedicated pedestrian path
- `path`: Shared use path (hiking, cycling)
- `pedestrian`: Pedestrian streets/zones
- `track`: Agricultural/forestry tracks
- `bridleway`: Horse riding paths
- `cycleway`: Dedicated cycle paths
- `steps`: Stairs/steps

### Surface Tags
- `paved`, `asphalt`, `concrete`: Hard surfaces
- `gravel`, `fine_gravel`: Medium surfaces
- `dirt`, `earth`, `grass`: Soft surfaces
- `wood`: Boardwalks
- `sand`: Beach paths

### Accessibility Tags
- `wheelchair=yes/no/limited`: Wheelchair access
- `stroller=yes/no`: Stroller friendly
- `width`: Path width in meters
- `surface`: Path surface material

### Access Tags
- `access=yes/no/private/permissive`
- `foot=yes/no/designated`
- `bicycle=yes/no/designated`

## Integration with OSRM

Pass high-quality paths to OSRM for routing:

```swift
let paths = await repository.findPathsForRouting(start: start, end: end)
let pedestrianPaths = paths.filter { $0.isPedestrian }

// Use path coordinates as waypoints or preferences
// OSRM will prefer routes using these paths
```

## Testing Queries

Use Overpass Turbo for testing: https://overpass-turbo.eu/

Example test query (London):
```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](51.500,-0.130,51.510,-0.120);
  way["highway"="path"](51.500,-0.130,51.510,-0.120);
);
out geom;
```

## Error Handling

```swift
do {
    let paths = try await repository.fetchWalkingPaths(bounds: bounds)
} catch NetworkError.timeout {
    print("Overpass API timeout - try smaller bounds")
} catch NetworkError.invalidResponse {
    print("Invalid response - check Overpass API status")
} catch {
    print("Failed to fetch paths: \(error)")
}
```

## Future Enhancements

- [ ] Path elevation profiles
- [ ] Real-time path conditions (mud, flooding)
- [ ] User-submitted path ratings
- [ ] Offline path caching with CoreData
- [ ] Path difficulty ratings
- [ ] Integration with weather data
- [ ] Park and trail networks
- [ ] Multi-use path conflict detection
