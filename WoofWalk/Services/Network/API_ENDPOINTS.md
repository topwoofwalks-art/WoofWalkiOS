# API Endpoints Ported - Android to iOS

## Summary
Successfully ported 3 external API services and 1 Firebase service from Android Retrofit/OkHttp to iOS URLSession with async/await pattern.

## Ported Services

### 1. OsrmService (OSRM Routing API)
**Base URL:** `https://router.project-osrm.org/`

**Endpoints:**

| Method | Android | iOS | Description |
|--------|---------|-----|-------------|
| GET | `route/v1/foot/{coordinates}` | `getRoute(coordinates:overview:geometries:steps:alternatives:)` | Get pedestrian route between coordinates |
| GET | `nearest/v1/foot/{coordinates}` | `getNearest(coordinates:number:)` | Find nearest road/waypoint |

**Parameters:**
- `coordinates`: String (format: "lng1,lat1;lng2,lat2;...")
- `overview`: String (default: "full")
- `geometries`: String (default: "polyline")
- `steps`: Bool (default: true)
- `alternatives`: Bool (default: true)
- `continueStraight`: Bool? (optional)
- `bearings`: String? (optional)
- `radiuses`: String? (optional)
- `number`: Int (default: 1)

**Response Models:**
- OsrmRouteResponse (code, routes[], waypoints[], message)
- OsrmRoute (geometry, legs[], distance, duration)
- OsrmLeg (steps[], distance, duration)
- OsrmStep (geometry, distance, duration, name, mode)
- OsrmWaypoint (name, location[])
- OsrmNearestResponse (code, waypoints[], message)
- OsrmNearestWaypoint (location[], name, distance)

**Convenience Methods Added:**
- `getRoute(from:to:waypoints:)` - Accepts coordinate tuples instead of string
- `getNearestRoad(latitude:longitude:)` - Simplified nearest road lookup

---

### 2. OverpassService (OpenStreetMap Overpass API)
**Base URL:** `https://overpass-api.de/api/`

**Endpoints:**

| Method | Android | iOS | Description |
|--------|---------|-----|-------------|
| GET | `interpreter?data={query}` | `query(_:)` | Execute Overpass QL query |

**Parameters:**
- `query`: String (Overpass QL syntax)

**Response Models:**
- OverpassResponse (elements[])
- OverpassElement (type, id, lat, lon, tags{})

**Query Builder:**
- `buildDogFriendlyQuery(latitude:longitude:radiusMeters:)` - Static method to generate POI query

**POI Types in Query:**
- Amenities: dog_park, drinking_water, waste_basket, bench, fountain, place_of_worship
- Leisure: park, picnic_table, picnic_site
- Natural: water, peak, hill, waterfall
- Tourism: viewpoint, attraction

**Convenience Methods Added:**
- `fetchDogFriendlyPOIs(latitude:longitude:radiusMeters:)` - Executes dog-friendly query

---

### 3. DirectionsService (Google Directions API)
**Base URL:** `https://maps.googleapis.com/maps/api/`

**Endpoints:**

| Method | Android | iOS | Description |
|--------|---------|-----|-------------|
| GET | `directions/json` | `getDirections(origin:destination:mode:alternatives:avoid:waypoints:)` | Get directions between locations |

**Parameters:**
- `origin`: String (address or "lat,lng")
- `destination`: String (address or "lat,lng")
- `mode`: String (default: "walking")
- `alternatives`: Bool (default: true)
- `avoid`: String? (optional: "tolls", "highways", "ferries")
- `waypoints`: String? (optional: "lat1,lng1|lat2,lng2")
- `key`: String (API key)

**Response Models:**
- DirectionsResponse (routes[], status)
- DirectionsRoute (summary, overviewPolyline, legs[], warnings[], bounds)
- OverviewPolyline (points)
- DirectionsLeg (distance, duration, startLocation, endLocation, steps[])
- DirectionsStep (htmlInstructions, distance, duration, startLocation, endLocation, polyline, travelMode, maneuver)
- Distance (value, text)
- Duration (value, text)
- Location (lat, lng)
- Bounds (northeast, southwest)

**Convenience Methods Added:**
- `getDirections(from:to:mode:alternatives:avoid:waypoints:)` - Accepts coordinate tuples

---

### 4. FirebaseService (Firebase Auth, Firestore, Storage)
**Platform:** Firebase SDK

**Authentication Endpoints:**

| Method | Android | iOS | Description |
|--------|---------|-----|-------------|
| - | `signIn(email, password)` | `signIn(email:password:)` | Email/password sign in |
| - | `createUser(email, password)` | `signUp(email:password:)` | User registration |
| - | `signOut()` | `signOut()` | Sign out current user |
| - | `sendPasswordReset(email)` | `resetPassword(email:)` | Password reset |

**Firestore Endpoints:**

| Method | Android | iOS | Description |
|--------|---------|-----|-------------|
| - | `collection().document().get()` | `getDocument(collection:documentId:)` | Fetch single document |
| - | `collection().get()` | `getDocuments(collection:)` | Fetch all documents |
| - | `collection().document().set()` | `setDocument(collection:documentId:data:)` | Create/update document |
| - | `collection().document().update()` | `updateDocument(collection:documentId:fields:)` | Partial update |
| - | `collection().document().delete()` | `deleteDocument(collection:documentId:)` | Delete document |
| - | `collection().whereEqualTo().get()` | `queryDocuments(collection:field:isEqualTo:)` | Query with filter |

**Storage Endpoints:**

| Method | Android | iOS | Description |
|--------|---------|-----|-------------|
| - | `putBytes()` | `uploadImage(data:path:)` | Upload image |
| - | `getBytes()` | `downloadImage(path:)` | Download image |
| - | `delete()` | `deleteFile(path:)` | Delete file |

**Configuration:**
- Persistence enabled
- Unlimited cache size
- Auto-converts snake_case ↔ camelCase

---

## Network Infrastructure

### NetworkManager
**Singleton Pattern:** `NetworkManager.shared`

**Configuration:**
- Connect timeout: 10s
- Read timeout: 15s
- Memory cache: 20MB
- Disk cache: 100MB
- Max connections per host: 5
- Retry count: 2 (exponential backoff)
- Cache policy: returnCacheDataElseLoad
- Waits for connectivity

**Generic Request Method:**
```swift
func request<T: Decodable>(
    url: URL,
    method: HTTPMethod,
    parameters: [String: Any]?,
    body: Encodable?,
    cachePolicy: URLRequest.CachePolicy,
    retryCount: Int
) async throws -> T
```

### NetworkError
Comprehensive error handling:
- `invalidURL`
- `invalidResponse`
- `httpError(statusCode: Int)`
- `decodingError(Error)`
- `encodingError(Error)`
- `noData`
- `serverError(message: String)`
- `timeout`
- `noConnection`
- `unknown(Error)`

All errors conform to `LocalizedError` for user-friendly messages.

---

## Migration Highlights

### Technology Stack
| Android | iOS |
|---------|-----|
| Retrofit 2 | URLSession |
| OkHttp 3 | URLSession |
| Gson | Codable (JSONDecoder/JSONEncoder) |
| Coroutines (suspend) | async/await |
| Hilt DI (@Provides) | Singleton pattern |

### Key Differences
1. **Async Pattern**: `suspend fun` → `async throws func`
2. **Error Handling**: Try-catch in Kotlin → do-try-catch in Swift
3. **JSON Conversion**: Gson annotations → CodingKeys (auto via convertFromSnakeCase)
4. **Dependency Injection**: Hilt modules → Static shared instances
5. **Default Parameters**: Both support, syntax slightly different

### Improvements in iOS Version
1. **Retry Logic**: Exponential backoff with configurable retry count
2. **Convenience Methods**: Coordinate tuple overloads for cleaner API
3. **Type Safety**: Codable protocol ensures compile-time safety
4. **Caching**: Built-in URLCache with configurable policies
5. **Error Propagation**: Strongly-typed NetworkError enum
6. **Firebase Integration**: Unified service with Auth, Firestore, Storage

---

## Usage Comparison

### Android (Retrofit)
```kotlin
// Hilt injection
@Inject lateinit var osrmService: OsrmService

// Usage
val response = osrmService.getRoute(coordinates = "lng1,lat1;lng2,lat2")
```

### iOS (URLSession)
```swift
// Direct instantiation
let osrmService = OsrmService()

// Usage
let response = try await osrmService.getRoute(
    from: (latitude: lat1, longitude: lng1),
    to: (latitude: lat2, longitude: lng2)
)
```

---

## Testing Endpoints

All endpoints can be tested with:
1. OSRM: Public API, no auth required
2. Overpass: Public API, no auth required
3. Google Directions: Requires API key in GoogleService-Info.plist
4. Firebase: Requires Firebase project configuration

---

## Files Created

1. **NetworkError.swift** - Error definitions
2. **NetworkManager.swift** - Base HTTP client
3. **OsrmModels.swift** - OSRM response models
4. **OsrmService.swift** - OSRM API client
5. **OverpassModels.swift** - Overpass response models
6. **OverpassService.swift** - Overpass API client
7. **DirectionsModels.swift** - Google Directions response models
8. **DirectionsService.swift** - Google Directions API client
9. **FirebaseService.swift** - Firebase unified service
10. **README.md** - Documentation
11. **API_ENDPOINTS.md** - This file

**Total: 11 files created in `/mnt/c/app/WoofWalkiOS/WoofWalk/Services/Network/`**

---

## Next Steps

1. Add these files to Xcode project
2. Configure GoogleService-Info.plist with API keys
3. Import FirebaseAuth, FirebaseFirestore, FirebaseStorage in Xcode
4. Test each service with sample requests
5. Integrate with ViewModels/Repositories
6. Add unit tests for network layer
7. Consider adding Alamofire if more advanced features needed (currently using native URLSession)

---

**Timestamp:** 2025-10-23
**Port Status:** COMPLETE
**Lines of Code:** ~500+ Swift code, ~200 documentation
**API Coverage:** 100% of Android endpoints ported
