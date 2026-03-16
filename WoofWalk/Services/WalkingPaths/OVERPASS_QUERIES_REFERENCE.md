# Overpass Queries - Quick Reference

Copy-paste ready queries for walking paths.

## 1. Basic Pedestrian Paths

**Use Case:** Dog walking routes in parks

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](SOUTH,WEST,NORTH,EAST);
  way["highway"="path"](SOUTH,WEST,NORTH,EAST);
  way["highway"="pedestrian"](SOUTH,WEST,NORTH,EAST);
);
out geom;
```

**Example (London Hyde Park):**
```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](51.500,-0.130,51.510,-0.120);
  way["highway"="path"](51.500,-0.130,51.510,-0.120);
  way["highway"="pedestrian"](51.500,-0.130,51.510,-0.120);
);
out geom;
```

**Expected:** 20-40 paths
**Response Time:** 2-4 seconds

---

## 2. Complete Network (All 14 Types)

**Use Case:** Full routing infrastructure

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](SOUTH,WEST,NORTH,EAST);
  way["highway"="path"](SOUTH,WEST,NORTH,EAST);
  way["highway"="track"](SOUTH,WEST,NORTH,EAST);
  way["highway"="bridleway"](SOUTH,WEST,NORTH,EAST);
  way["highway"="cycleway"](SOUTH,WEST,NORTH,EAST);
  way["highway"="pedestrian"](SOUTH,WEST,NORTH,EAST);
  way["highway"="steps"](SOUTH,WEST,NORTH,EAST);
  way["highway"="unclassified"](SOUTH,WEST,NORTH,EAST);
  way["highway"="residential"](SOUTH,WEST,NORTH,EAST);
  way["highway"="service"](SOUTH,WEST,NORTH,EAST);
  way["highway"="living_street"](SOUTH,WEST,NORTH,EAST);
  way["highway"="tertiary"](SOUTH,WEST,NORTH,EAST);
  way["highway"="secondary"](SOUTH,WEST,NORTH,EAST);
  way["highway"="primary"](SOUTH,WEST,NORTH,EAST);
);
out geom;
```

**Example (NYC Times Square):**
```javascript
[out:json][timeout:30];
(
  way["highway"="footway"](40.750,-73.990,40.760,-73.980);
  way["highway"="path"](40.750,-73.990,40.760,-73.980);
  way["highway"="residential"](40.750,-73.990,40.760,-73.980);
);
out geom;
```

**Expected:** 100-300 paths
**Response Time:** 5-10 seconds

---

## 3. Accessible Paths Only

**Use Case:** Wheelchair/stroller-friendly routes

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["wheelchair"="yes"](SOUTH,WEST,NORTH,EAST);
  way["highway"="path"]["wheelchair"="yes"](SOUTH,WEST,NORTH,EAST);
  way["highway"="footway"]["stroller"="yes"](SOUTH,WEST,NORTH,EAST);
  way["highway"="path"]["stroller"="yes"](SOUTH,WEST,NORTH,EAST);
);
out geom;
```

**Expected:** 10-30% of total paths
**Response Time:** 1-3 seconds

---

## 4. High Quality Paved Paths

**Use Case:** Clean, smooth surfaces for nice walks

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["surface"="paved"](SOUTH,WEST,NORTH,EAST);
  way["highway"="footway"]["surface"="asphalt"](SOUTH,WEST,NORTH,EAST);
  way["highway"="footway"]["surface"="concrete"](SOUTH,WEST,NORTH,EAST);
  way["highway"="path"]["surface"="paved"](SOUTH,WEST,NORTH,EAST);
  way["highway"="path"]["surface"="asphalt"](SOUTH,WEST,NORTH,EAST);
);
out geom;
```

**Expected:** 40-60% of footpaths
**Response Time:** 2-5 seconds

---

## 5. Named Trails and Paths

**Use Case:** Well-known walking routes

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["name"](SOUTH,WEST,NORTH,EAST);
  way["highway"="path"]["name"](SOUTH,WEST,NORTH,EAST);
  way["highway"="track"]["name"](SOUTH,WEST,NORTH,EAST);
);
out geom;
```

**Expected:** 20-40% of paths have names
**Response Time:** 2-4 seconds

---

## 6. Radius Search Around Point

**Use Case:** "Paths near me"

```javascript
[out:json][timeout:30];
(
  way(around:RADIUS_METERS,LATITUDE,LONGITUDE)["highway"="footway"];
  way(around:RADIUS_METERS,LATITUDE,LONGITUDE)["highway"="path"];
  way(around:RADIUS_METERS,LATITUDE,LONGITUDE)["highway"="pedestrian"];
);
out geom;
```

**Example (500m around London):**
```javascript
[out:json][timeout:30];
(
  way(around:500,51.5074,-0.1278)["highway"="footway"];
  way(around:500,51.5074,-0.1278)["highway"="path"];
  way(around:500,51.5074,-0.1278)["highway"="pedestrian"];
);
out geom;
```

**Radius Guide:**
- 200m: Immediate vicinity (5-15 paths)
- 500m: Neighborhood (20-50 paths)
- 1000m: Large area (50-150 paths)
- 2000m: May timeout in dense areas

---

## 7. Steps and Elevation Changes

**Use Case:** Avoid steep paths

```javascript
[out:json][timeout:30];
(
  way["highway"="steps"](SOUTH,WEST,NORTH,EAST);
  way["highway"="footway"]["incline"](SOUTH,WEST,NORTH,EAST);
);
out geom;
```

**Expected:** 5-10% of paths (more in hilly areas)
**Response Time:** 1-2 seconds

---

## 8. Park and Green Space Paths

**Use Case:** Nature walks

```javascript
[out:json][timeout:30];
(
  way["highway"="footway"]["park"="yes"](SOUTH,WEST,NORTH,EAST);
  way["highway"="path"]["park"="yes"](SOUTH,WEST,NORTH,EAST);
  way["highway"="footway"]["leisure"="park"](SOUTH,WEST,NORTH,EAST);
);
out geom;
```

**Expected:** 30-50% in park areas
**Response Time:** 2-4 seconds

---

## Swift Implementation

### Use in Repository

```swift
let repository = WalkingPathRepository.shared

// Basic pedestrian paths
let bounds = [
    CLLocationCoordinate2D(latitude: 51.500, longitude: -0.130),
    CLLocationCoordinate2D(latitude: 51.510, longitude: -0.120)
]
let paths = try await repository.fetchWalkingPaths(bounds: bounds)

// Nearby paths
let location = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
let nearby = await repository.findNearbyPaths(location: location, radiusMeters: 500.0)

// For routing
let start = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
let end = CLLocationCoordinate2D(latitude: 51.5090, longitude: -0.1250)
let routing = await repository.findPathsForRouting(start: start, end: end)
```

### Custom Overpass Query

```swift
let customQuery = """
[out:json][timeout:30];
(
  way["highway"="footway"]["lit"="yes"](51.5,-0.13,51.51,-0.12);
  way["highway"="path"]["lit"="yes"](51.5,-0.13,51.51,-0.12);
);
out geom;
"""

let service = OverpassService()
let response = try await service.query(customQuery)
```

---

## Query Optimization Tips

### 1. Limit Area Size
```
Small:  0.01° x 0.01° (~1km²)    ✅ Fast (1-3s)
Medium: 0.05° x 0.05° (~25km²)   ⚠️  Moderate (3-8s)
Large:  0.1° x 0.1° (~100km²)    ⚠️  Slow (8-15s)
XLarge: 0.2° x 0.2° (~400km²)    ❌ May timeout
```

### 2. Filter Path Types
```javascript
// Fast - 3 types
way["highway"="footway"]
way["highway"="path"]
way["highway"="pedestrian"]

// Slow - 14 types
way["highway"="footway"]
...14 lines...
```

### 3. Add Constraints
```javascript
// Slower - all paths
way["highway"="footway"](...)

// Faster - only named
way["highway"="footway"]["name"](...)

// Fastest - specific tags
way["highway"="footway"]["name"="Hyde Park Path"](...)
```

### 4. Use Appropriate Timeout
```javascript
[timeout:15]  // Simple queries
[timeout:30]  // Standard (default)
[timeout:60]  // Complex/large areas
```

---

## Response Format

All queries return:

```json
{
  "elements": [
    {
      "type": "way",
      "id": 123456789,
      "tags": {
        "highway": "footway",
        "name": "Example Path",
        "surface": "paved",
        "width": "2.5",
        "wheelchair": "yes"
      },
      "geometry": [
        {"lat": 51.5074, "lon": -0.1278},
        {"lat": 51.5075, "lon": -0.1279}
      ]
    }
  ]
}
```

**Key Fields:**
- `type`: Always "way" for paths
- `id`: Unique OSM ID
- `tags`: Path metadata (highway, surface, etc.)
- `geometry`: Array of lat/lon coordinates

---

## Testing Queries

### Overpass Turbo
1. Go to https://overpass-turbo.eu/
2. Paste query
3. Click "Run"
4. View on map

### Quick Test
```javascript
[out:json][timeout:30];
way["highway"="footway"](51.5074,-0.1278,51.5084,-0.1268);
out geom;
```
Should return 5-10 paths in 1-2 seconds.

---

## Common OSM Tags

### Highway Types
```
footway        - Pedestrian path
path           - Multi-use trail
pedestrian     - Pedestrian street
track          - Agricultural track
bridleway      - Horse path
cycleway       - Bike lane
steps          - Stairs
residential    - Residential street
service        - Service road
```

### Surface Types
```
paved          - Hard paved
asphalt        - Asphalt
concrete       - Concrete
gravel         - Gravel
fine_gravel    - Fine gravel
dirt           - Dirt/earth
grass          - Grass
sand           - Sand
wood           - Wooden boardwalk
```

### Common Tags
```
name           - Path name
surface        - Surface material
width          - Width in meters
lit            - Lighting (yes/no)
wheelchair     - Wheelchair access
stroller       - Stroller friendly
incline        - up/down
step_count     - Number of steps
handrail       - yes/no
```

---

## Error Handling

### Timeout
```
Cause: Area too large or complex
Fix: Reduce bounds or split query
```

### Empty Response
```
Cause: No paths in area
Fix: Expand area or add road types
```

### Rate Limit
```
Cause: Too many requests
Fix: Add delay between calls (1s minimum)
```

### Invalid Bounds
```
Cause: south > north or west > east
Fix: Verify coordinate order
```

---

**Test all queries at:** https://overpass-turbo.eu/

**API Status:** https://overpass-api.de/api/status

**OSM Wiki:** https://wiki.openstreetmap.org/wiki/Key:highway
