# Dynamic World Service

Google Earth Engine integration for livestock field analysis using Dynamic World land cover data.

## Overview

DynamicWorldService provides real-time land cover classification and livestock suitability scoring for grazing fields using satellite imagery from Google Earth Engine's Dynamic World dataset.

## Architecture

```
DynamicWorldService (Singleton)
├── enrichFields() - Batch field enrichment
├── enrichSingleField() - Single field analysis
└── calculateLivestockSuitability() - Scoring algorithm

DynamicWorldCacheManager (Singleton)
├── 30-day cache expiration
├── File-based JSON cache
└── Automatic cleanup

Models
├── DynamicWorldData - Main data structure
├── LandCoverProbabilities - 9-class probabilities
├── LivestockSuitability - Scoring & rating
└── EnrichedField - API response format
```

## Land Cover Classes

Dynamic World provides probability scores (0-1) for 9 classes:

| Class | Index | Weight | Description |
|-------|-------|--------|-------------|
| Water | 0 | -0.30 | Bodies of water |
| Trees | 1 | +0.10 | Forest/woodland |
| Grass | 2 | +0.40 | Grassland/pasture |
| Flooded Vegetation | 3 | 0.00 | Wetlands |
| Crops | 4 | +0.25 | Agricultural land |
| Shrub & Scrub | 5 | +0.15 | Bushland |
| Built | 6 | -0.50 | Urban/developed |
| Bare | 7 | 0.00 | Exposed soil |
| Snow & Ice | 8 | 0.00 | Snow cover |

## Suitability Scoring

### Algorithm
```swift
score = (grass * 0.40) +
        (crops * 0.25) +
        (shrub * 0.15) +
        (trees * 0.10) +
        (built * -0.50) +
        (water * -0.30)
```

### Rating Scale
- **0-30**: Poor (Red)
- **30-50**: Fair (Orange)
- **50-70**: Good (Yellow)
- **70-100**: Excellent (Green)

## Usage

### Single Field Enrichment

```swift
let service = DynamicWorldService.shared

do {
    let data = try await service.enrichSingleField(
        fieldId: "field_123",
        lat: 40.7128,
        lng: -74.0060
    )

    print("Suitability: \(data.livestockSuitability.score)")
    print("Rating: \(data.livestockSuitability.rating)")
    print("Dominant: \(data.dominantClass)")
} catch {
    print("Enrichment failed: \(error)")
}
```

### Batch Enrichment

```swift
let fields = [
    FieldLocation(fieldId: "field_1", lat: 40.7128, lng: -74.0060),
    FieldLocation(fieldId: "field_2", lat: 40.7580, lng: -73.9855)
]

do {
    let response = try await service.enrichFields(fields)
    print("Enriched \(response.count) fields")

    for field in response.fields {
        print("\(field.fieldId): \(field.livestockSuitability)")
    }
} catch {
    print("Batch enrichment failed: \(error)")
}
```

### SwiftUI Integration

```swift
struct FieldDetailView: View {
    @StateObject var viewModel = DynamicWorldViewModel()
    let fieldId: String
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Analyzing field...")
            } else if let data = viewModel.enrichedData {
                DynamicWorldDetailView(data: data)
            }
        }
        .task {
            await viewModel.enrichField(
                fieldId: fieldId,
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )
        }
    }
}
```

## Caching Strategy

### Cache Behavior
- Cache location: `Library/Caches/DynamicWorld/`
- Format: JSON per field
- Expiration: 30 days
- Auto-cleanup: On app launch

### Cache Management

```swift
let service = DynamicWorldService.shared

try service.clearExpiredCache()

try service.clearCache()

if let cached = try service.getCachedData(forFieldId: "field_123") {
    print("Days until expiry: \(cached.daysUntilExpiry)")
}
```

## Firebase Cloud Function

The service calls `enrichFieldsWithDynamicWorld` Firebase Function:

### Request Format
```json
{
  "fields": [
    {
      "fieldId": "field_123",
      "lat": 40.7128,
      "lng": -74.0060,
      "bbox": [minLat, minLng, maxLat, maxLng]
    }
  ],
  "dateRange": {
    "start": "2024-01-01",
    "end": "2024-12-31"
  }
}
```

### Response Format
```json
{
  "success": true,
  "count": 1,
  "fields": [
    {
      "fieldId": "field_123",
      "probabilities": {
        "grass": 0.65,
        "trees": 0.15,
        "crops": 0.10,
        "water": 0.05,
        "built": 0.02,
        "shrubAndScrub": 0.03,
        "floodedVegetation": 0.00,
        "bare": 0.00,
        "snowAndIce": 0.00
      },
      "dominantClass": "grass",
      "livestockSuitability": 72.5,
      "timestamp": 1704067200000
    }
  ]
}
```

## UI Components

### LandCoverChartView
Displays pie chart of land cover distribution with legend.

```swift
LandCoverChartView(probabilities: data.landCover)
```

### SuitabilityScoreView
Shows circular progress indicator with rating color and metadata.

```swift
SuitabilityScoreView(
    suitability: data.livestockSuitability,
    lastUpdated: data.fetchedAt
)
```

### DynamicWorldDetailView
Complete field analysis view with charts and details.

```swift
DynamicWorldDetailView(data: data)
```

## Error Handling

```swift
enum DynamicWorldError: LocalizedError {
    case invalidResponse
    case noDataReturned
    case enrichmentFailed(String)
    case cacheError(String)
    case expiredData
}
```

## Performance Considerations

- Caching reduces API calls by ~90%
- Batch enrichment for multiple fields
- Background refresh on field view
- Auto-cleanup prevents cache bloat

## Background Refresh Pattern

```swift
func loadField() async {
    viewModel.loadCachedData(forFieldId: fieldId)

    if let data = viewModel.enrichedData {
        if data.daysUntilExpiry < 7 {
            await viewModel.refreshIfExpired(
                fieldId: fieldId,
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )
        }
    }
}
```

## Testing

```swift
let testProbs = LandCoverProbabilities(
    water: 0.05,
    trees: 0.20,
    grass: 0.45,
    floodedVegetation: 0.02,
    crops: 0.15,
    shrubAndScrub: 0.08,
    built: 0.03,
    bare: 0.02,
    snowAndIce: 0.00
)

let service = DynamicWorldService.shared
let score = service.calculateLivestockSuitability(testProbs)

assert(score >= 0 && score <= 100)
```

## Dependencies

- Firebase Functions
- SwiftUI Charts (iOS 16+)
- Combine

## Future Enhancements

- Historical trend analysis
- Seasonal variation tracking
- Custom scoring weights per region
- Multi-date comparison
- Field boundary polygon support
- Offline map tile caching
