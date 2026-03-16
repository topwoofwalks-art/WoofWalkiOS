# WoofWalk iOS Network Layer

Ported from Android Retrofit/OkHttp to iOS URLSession with async/await.

## Architecture

### Base Components
- **NetworkManager.swift**: Singleton URLSession manager with retry logic, caching, exponential backoff
- **NetworkError.swift**: Comprehensive error handling for all network scenarios
- **HTTPMethod.swift**: Enum for HTTP methods (GET, POST, PUT, DELETE, PATCH)

### Services

#### OsrmService
Routes pedestrian navigation using OSRM API.

**Endpoints:**
- `getRoute(coordinates:overview:geometries:steps:alternatives:)` - GET /route/v1/foot/{coordinates}
- `getNearest(coordinates:number:)` - GET /nearest/v1/foot/{coordinates}
- `getRoute(from:to:waypoints:)` - Convenience method with coordinate tuples
- `getNearestRoad(latitude:longitude:)` - Find nearest walkable road

**Models:** OsrmRouteResponse, OsrmRoute, OsrmLeg, OsrmStep, OsrmWaypoint, OsrmNearestResponse

#### OverpassService
Fetches POIs from OpenStreetMap using Overpass API.

**Endpoints:**
- `query(_:)` - GET /interpreter?data={query}
- `buildDogFriendlyQuery(latitude:longitude:radiusMeters:)` - Static builder for dog-friendly POI query
- `fetchDogFriendlyPOIs(latitude:longitude:radiusMeters:)` - Convenience method

**POI Types Queried:**
- dog_park, drinking_water, waste_basket, park, bench
- water, fountain, place_of_worship
- peak, hill, viewpoint, waterfall
- attraction, picnic_site, picnic_table

**Models:** OverpassResponse, OverpassElement

#### DirectionsService
Google Directions API for route planning.

**Endpoints:**
- `getDirections(origin:destination:mode:alternatives:avoid:waypoints:)` - GET /directions/json
- `getDirections(from:to:mode:alternatives:avoid:waypoints:)` - Convenience method with coordinates

**Models:** DirectionsResponse, DirectionsRoute, DirectionsLeg, DirectionsStep, Location, Distance, Duration, Bounds

#### FirebaseService
Firebase Auth, Firestore, Storage integration.

**Auth:**
- `signIn(email:password:)` - Email/password authentication
- `signUp(email:password:)` - User registration
- `signOut()` - Sign out current user
- `resetPassword(email:)` - Password reset flow

**Firestore:**
- `getDocument(collection:documentId:)` - Fetch single document
- `getDocuments(collection:)` - Fetch all documents in collection
- `setDocument(collection:documentId:data:)` - Create/update document
- `updateDocument(collection:documentId:fields:)` - Partial update
- `deleteDocument(collection:documentId:)` - Delete document
- `queryDocuments(collection:field:isEqualTo:)` - Query with filter

**Storage:**
- `uploadImage(data:path:)` - Upload image, returns download URL
- `downloadImage(path:)` - Download image data
- `deleteFile(path:)` - Delete file from storage

## Features

### Retry Logic
- Automatic retry on failure (configurable, default 2 retries)
- Exponential backoff (1s, 2s, 4s...)
- Handles timeout, no connection, server errors

### Caching
- 20MB memory cache, 100MB disk cache
- Default policy: returnCacheDataElseLoad
- Can override per request

### Error Handling
- NetworkError enum with LocalizedError
- Specific errors: invalidURL, httpError, decodingError, timeout, noConnection
- Propagates with detailed messages

### Configuration
- 10s connect timeout
- 15s read timeout
- 5 max connections per host
- Waits for connectivity
- JSON content-type headers

### Codable Integration
- All models conform to Codable
- JSONDecoder with convertFromSnakeCase for API compatibility
- Clean Swift naming conventions

## Usage Examples

### OSRM Routing
```swift
let osrmService = OsrmService()
let response = try await osrmService.getRoute(
    from: (latitude: 37.7749, longitude: -122.4194),
    to: (latitude: 37.7849, longitude: -122.4094)
)
```

### Overpass POI Search
```swift
let overpassService = OverpassService()
let pois = try await overpassService.fetchDogFriendlyPOIs(
    latitude: 37.7749,
    longitude: -122.4194,
    radiusMeters: 1500
)
```

### Google Directions
```swift
let directionsService = DirectionsService(apiKey: "YOUR_API_KEY")
let directions = try await directionsService.getDirections(
    from: (37.7749, -122.4194),
    to: (37.7849, -122.4094),
    mode: "walking",
    alternatives: true
)
```

### Firebase Auth
```swift
let firebase = FirebaseService.shared
let user = try await firebase.signIn(email: "user@example.com", password: "password")
```

### Firestore
```swift
let firebase = FirebaseService.shared
try await firebase.setDocument(collection: "walks", documentId: walkId, data: walkData)
let walk: Walk = try await firebase.getDocument(collection: "walks", documentId: walkId)
```

## Migration Notes from Android

### OkHttp → URLSession
- Connection pool: 5 connections, 30s keep-alive
- Timeouts: 10s connect, 15s read, 10s write
- Retry on connection failure enabled

### Retrofit → NetworkManager
- Suspend functions → async/await
- Retrofit interfaces → Service classes
- @GET/@POST annotations → method parameters
- @Path/@Query → URL building in methods

### Gson → Codable
- GsonConverterFactory → JSONDecoder/JSONEncoder
- @SerializedName → CodingKeys (handled by convertFromSnakeCase)
- Default values in Kotlin data classes → Swift initializers

### Dependency Injection
- Hilt @Provides → Static shared instances or init parameters
- @Singleton → Static let shared or manual lifecycle

## Base URLs
- OSRM: https://router.project-osrm.org/
- Overpass: https://overpass-api.de/api/
- Google Directions: https://maps.googleapis.com/maps/api/
- Firebase: Configured via GoogleService-Info.plist
