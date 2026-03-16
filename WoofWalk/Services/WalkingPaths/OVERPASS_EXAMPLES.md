# Overpass API Query Examples

Real-world examples with expected responses for testing the walking paths system.

## Test Locations

### London, UK
- Center: 51.5074, -0.1278
- Sample bounds: (51.500, -0.130, 51.510, -0.120)

### New York, USA
- Center: 40.7580, -73.9855
- Sample bounds: (40.750, -73.990, 40.760, -73.980)

### Sydney, Australia
- Center: -33.8688, 151.2093
- Sample bounds: (-33.875, 151.200, -33.865, 151.210)

## Query Examples with Expected Results

### 1. Basic Footpaths Query (London Hyde Park)

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](51.500,-0.130,51.510,-0.120);
  way["highway"="path"](51.500,-0.130,51.510,-0.120);
);
out geom;
```

**Expected Response:**
```json
{
  "elements": [
    {
      "type": "way",
      "id": 123456789,
      "tags": {
        "highway": "footway",
        "name": "Hyde Park Path",
        "surface": "paved",
        "width": "3"
      },
      "geometry": [
        {"lat": 51.5074, "lon": -0.1278},
        {"lat": 51.5075, "lon": -0.1279},
        {"lat": 51.5076, "lon": -0.1280}
      ]
    },
    {
      "type": "way",
      "id": 987654321,
      "tags": {
        "highway": "path",
        "surface": "gravel",
        "wheelchair": "yes"
      },
      "geometry": [
        {"lat": 51.5080, "lon": -0.1275},
        {"lat": 51.5081, "lon": -0.1274}
      ]
    }
  ]
}
```

### 2. Accessible Paths Only

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["wheelchair"="yes"](51.500,-0.130,51.510,-0.120);
  way["highway"="path"]["wheelchair"="yes"](51.500,-0.130,51.510,-0.120);
  way["highway"="footway"]["stroller"="yes"](51.500,-0.130,51.510,-0.120);
);
out geom;
```

**Expected Response:**
```json
{
  "elements": [
    {
      "type": "way",
      "id": 111222333,
      "tags": {
        "highway": "footway",
        "surface": "asphalt",
        "wheelchair": "yes",
        "width": "2.5"
      },
      "geometry": [
        {"lat": 51.5074, "lon": -0.1278},
        {"lat": 51.5075, "lon": -0.1277}
      ]
    }
  ]
}
```

### 3. Radius Search (500m around point)

```javascript
[out:json][timeout:30];
(
  way(around:500,51.5074,-0.1278)["highway"="footway"];
  way(around:500,51.5074,-0.1278)["highway"="path"];
  way(around:500,51.5074,-0.1278)["highway"="pedestrian"];
);
out geom;
```

**Expected:** 20-50 paths in central London

### 4. Named Trails Only

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["name"](51.500,-0.130,51.510,-0.120);
  way["highway"="path"]["name"](51.500,-0.130,51.510,-0.120);
);
out geom;
```

**Expected Response:**
```json
{
  "elements": [
    {
      "type": "way",
      "id": 444555666,
      "tags": {
        "highway": "path",
        "name": "Serpentine Path",
        "surface": "paved",
        "lit": "yes"
      },
      "geometry": [
        {"lat": 51.5050, "lon": -0.1270},
        {"lat": 51.5051, "lon": -0.1271},
        {"lat": 51.5052, "lon": -0.1272}
      ]
    }
  ]
}
```

### 5. Complete Path Network (14 types)

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](40.750,-73.990,40.760,-73.980);
  way["highway"="path"](40.750,-73.990,40.760,-73.980);
  way["highway"="track"](40.750,-73.990,40.760,-73.980);
  way["highway"="bridleway"](40.750,-73.990,40.760,-73.980);
  way["highway"="cycleway"](40.750,-73.990,40.760,-73.980);
  way["highway"="pedestrian"](40.750,-73.990,40.760,-73.980);
  way["highway"="steps"](40.750,-73.990,40.760,-73.980);
  way["highway"="unclassified"](40.750,-73.990,40.760,-73.980);
  way["highway"="residential"](40.750,-73.990,40.760,-73.980);
  way["highway"="service"](40.750,-73.990,40.760,-73.980);
  way["highway"="living_street"](40.750,-73.990,40.760,-73.980);
);
out geom;
```

**Expected:** 100+ ways in NYC Times Square area

### 6. Surface Quality Filter

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["surface"~"paved|asphalt|concrete"]
    (51.500,-0.130,51.510,-0.120);
  way["highway"="path"]["surface"~"paved|asphalt|concrete"]
    (51.500,-0.130,51.510,-0.120);
);
out geom;
```

**Expected:** High-quality paved paths only

### 7. Park Paths

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["park"="yes"](51.500,-0.130,51.510,-0.120);
  way["highway"="path"]["park"="yes"](51.500,-0.130,51.510,-0.120);
  way["highway"="footway"]["leisure"="park"](51.500,-0.130,51.510,-0.120);
);
out geom;
```

### 8. Steps and Stairs

```javascript
[out:json][timeout:30];
(
  way["highway"="steps"](51.500,-0.130,51.510,-0.120);
  way["highway"="footway"]["incline"="up"](51.500,-0.130,51.510,-0.120);
);
out geom;
```

**Expected Response:**
```json
{
  "elements": [
    {
      "type": "way",
      "id": 777888999,
      "tags": {
        "highway": "steps",
        "step_count": "24",
        "handrail": "yes",
        "incline": "up"
      },
      "geometry": [
        {"lat": 51.5074, "lon": -0.1278},
        {"lat": 51.5075, "lon": -0.1278}
      ]
    }
  ]
}
```

## Swift Code to Execute Queries

### Fetch and Parse

```swift
let repository = WalkingPathRepository.shared

// London Hyde Park bounds
let bounds = [
    CLLocationCoordinate2D(latitude: 51.500, longitude: -0.130),
    CLLocationCoordinate2D(latitude: 51.510, longitude: -0.120)
]

do {
    let paths = try await repository.fetchWalkingPaths(bounds: bounds)

    print("Found \(paths.count) paths")

    for path in paths {
        print("\(path.pathType.displayName): \(path.name ?? "Unnamed")")
        print("  Length: \(String(format: "%.0fm", path.length))")
        print("  Surface: \(path.surface ?? "unknown")")
        print("  Quality: \(String(format: "%.1f", path.qualityScore))")
    }
} catch {
    print("Error: \(error)")
}
```

### Radius Search

```swift
// Times Square, NYC
let location = CLLocationCoordinate2D(
    latitude: 40.7580,
    longitude: -73.9855
)

let nearbyPaths = await repository.findNearbyPaths(
    location: location,
    radiusMeters: 500.0
)

print("Found \(nearbyPaths.count) paths within 500m")
```

## Interpreting Results

### Path Type Distribution

Typical urban area (1km x 1km):
- Footways: 40-60%
- Residential: 20-30%
- Paths: 10-20%
- Service roads: 5-10%
- Cycleways: 5-10%
- Steps: 2-5%
- Other: 5-10%

### Quality Scores

Score ranges by path type:
- 12-15: Premium footpaths (paved, wide, accessible)
- 10-12: Good footpaths (basic footways)
- 8-10: Shared paths and tracks
- 6-8: Residential streets
- 4-6: Service roads
- 2-4: Major roads
- 0-2: Unknown/poor quality

### Typical Response Times

- Small area (0.01° x 0.01°): 1-3 seconds
- Medium area (0.05° x 0.05°): 3-8 seconds
- Large area (0.1° x 0.1°): 8-15 seconds
- Very large (0.2° x 0.2°): 15-30 seconds (may timeout)

## Testing with Overpass Turbo

1. Visit https://overpass-turbo.eu/
2. Paste query in left panel
3. Click "Run"
4. View results on map and in data tab

### Quick Test Query (London)

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](51.5074,-0.1278,51.5084,-0.1268);
  way["highway"="path"](51.5074,-0.1278,51.5084,-0.1268);
);
out geom;
```

This should return ~10-20 paths in central London.

## Common Issues and Solutions

### Issue: Empty Response

**Cause:** Area has no OSM footpath data
**Solution:** Try broader path types (include residential)

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](south,west,north,east);
  way["highway"="path"](south,west,north,east);
  way["highway"="residential"](south,west,north,east);
);
out geom;
```

### Issue: Timeout

**Cause:** Area too large or complex
**Solution:** Reduce bounds or split into smaller queries

```swift
// Split large area into grid
let gridSize = 0.02 // degrees
for lat in stride(from: south, to: north, by: gridSize) {
    for lon in stride(from: west, to: east, by: gridSize) {
        let bounds = [
            CLLocationCoordinate2D(latitude: lat, longitude: lon),
            CLLocationCoordinate2D(latitude: lat + gridSize, longitude: lon + gridSize)
        ]
        let paths = try await repository.fetchWalkingPaths(bounds: bounds)
    }
}
```

### Issue: Missing Geometry

**Cause:** Query missing `out geom`
**Solution:** Always include geometry output

```javascript
// WRONG - no geometry
out body;

// CORRECT - includes geometry
out geom;
```

### Issue: Coordinates Empty

**Cause:** Element is node, not way
**Solution:** Filter for ways only in parsing

```swift
let paths = response.elements.compactMap { element in
    guard element.type == "way",
          let geometry = element.geometry,
          geometry.count >= 2 else {
        return nil
    }
    // Process way...
}
```

## Performance Optimization

### Batch Queries for Multiple Areas

```swift
actor PathBatchLoader {
    func loadMultipleAreas(areas: [(south: Double, west: Double, north: Double, east: Double)]) async throws -> [WalkingPath] {
        var allPaths: [WalkingPath] = []

        for area in areas {
            let paths = try await repository.fetchWalkingPaths(bounds: [
                CLLocationCoordinate2D(latitude: area.south, longitude: area.west),
                CLLocationCoordinate2D(latitude: area.north, longitude: area.east)
            ])
            allPaths.append(contentsOf: paths)
        }

        return allPaths
    }
}
```

### Progressive Loading

```swift
// Load high-priority paths first
let footpathQuery = """
[out:json][timeout:15];
(
  way["highway"="footway"](south,west,north,east);
  way["highway"="path"](south,west,north,east);
  way["highway"="pedestrian"](south,west,north,east);
);
out geom;
"""

// Then load secondary paths
let secondaryQuery = """
[out:json][timeout:15];
(
  way["highway"="residential"](south,west,north,east);
  way["highway"="service"](south,west,north,east);
);
out geom;
"""
```

## Validation Tests

### Verify Response Structure

```swift
func validatePathResponse(_ path: WalkingPath) -> Bool {
    guard !path.id.isEmpty else {
        print("Invalid: Empty ID")
        return false
    }

    guard path.coordinates.count >= 2 else {
        print("Invalid: Less than 2 coordinates")
        return false
    }

    guard path.length > 0 else {
        print("Invalid: Zero length")
        return false
    }

    guard path.pathType != .unknown else {
        print("Warning: Unknown path type")
        return true // Still valid but suspicious
    }

    return true
}
```

### Expected Data Quality

```swift
let paths = try await repository.fetchWalkingPaths(bounds: bounds)

let namedPaths = paths.filter { $0.name != nil }
let surfacedPaths = paths.filter { $0.surface != nil }
let widthPaths = paths.filter { $0.osmTags["width"] != nil }

print("Named: \(namedPaths.count)/\(paths.count) (\(namedPaths.count * 100 / paths.count)%)")
print("Surface: \(surfacedPaths.count)/\(paths.count)")
print("Width: \(widthPaths.count)/\(paths.count)")

// Urban area should have:
// - 20-40% named paths
// - 50-70% with surface data
// - 10-30% with width data
```
